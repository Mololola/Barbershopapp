from contextlib import asynccontextmanager

from apscheduler.schedulers.background import BackgroundScheduler
from fastapi import FastAPI, Request
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.api.billing import router as billing_router
from app.api.bookings import router as bookings_router
from app.api.rewards import router as rewards_router
from app.core.rate_limit import _rate_limit_exceeded_handler, limiter
from app.db.session import SessionLocal
from app.jobs.expire_grace_periods import find_and_delete_expired_businesses

scheduler = BackgroundScheduler()


def _run_expire_grace_periods() -> None:
    db = SessionLocal()
    try:
        find_and_delete_expired_businesses(db)
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
app.include_router(bookings_router)
app.include_router(rewards_router)
app.include_router(billing_router)


@app.get("/health")
@limiter.exempt
def health(request: Request) -> dict[str, str]:
    return {"status": "ok"}
