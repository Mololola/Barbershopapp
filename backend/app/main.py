import logging
import time
from contextlib import asynccontextmanager

from apscheduler.schedulers.background import BackgroundScheduler
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.api.account import router as account_router
from app.api.billing import router as billing_router
from app.api.bookings import router as bookings_router
from app.api.rewards import router as rewards_router
from app.core.logging import configure_logging
from app.core.rate_limit import _rate_limit_exceeded_handler, limiter
from app.db.session import SessionLocal
from app.jobs.expire_grace_periods import find_and_delete_expired_businesses

configure_logging()
logger = logging.getLogger(__name__)

scheduler = BackgroundScheduler()


def _run_expire_grace_periods() -> None:
    db = SessionLocal()
    try:
        find_and_delete_expired_businesses(db)
    except Exception:
        # A scheduled job's exception never reaches a request/response
        # cycle, so nothing else in this app would ever surface it —
        # without this, a failing day-one billing-cleanup run just goes
        # silently missing, every day, with no trace anywhere.
        logger.exception("expire_grace_periods job failed")
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # No cron/deployment infra exists yet (everything runs via `uvicorn
    # --reload` locally) — an in-process scheduler is the pragmatic choice
    # for now; revisit once there's a real host with its own scheduled-task
    # feature.
    scheduler.add_job(_run_expire_grace_periods, "interval", days=1, id="expire_grace_periods")
    scheduler.start()
    yield
    scheduler.shutdown()


app = FastAPI(title="Barbershop API", lifespan=lifespan)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """The one place every request passes through — logs method/path/status
    /duration for all of them, and is where an unhandled exception (one no
    route's own try/except caught) becomes visible at all instead of just
    crashing the response with no record of what request caused it."""
    start = time.monotonic()
    try:
        response = await call_next(request)
    except Exception:
        logger.exception("Unhandled exception on %s %s", request.method, request.url.path)
        return JSONResponse(status_code=500, content={"detail": "Something went wrong. Please try again."})
    duration_ms = (time.monotonic() - start) * 1000
    logger.info("%s %s -> %d (%.0fms)", request.method, request.url.path, response.status_code, duration_ms)
    return response


app.include_router(bookings_router)
app.include_router(rewards_router)
app.include_router(billing_router)
app.include_router(account_router)


@app.get("/health")
@limiter.exempt
def health(request: Request) -> dict[str, str]:
    return {"status": "ok"}
