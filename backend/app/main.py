import logging
import time

import sentry_sdk
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.api.account import router as account_router
from app.api.admin import router as admin_router
from app.api.auth_bridge import router as auth_bridge_router
from app.api.billing import router as billing_router
from app.api.billing_return import router as billing_return_router
from app.api.delete_account_page import router as delete_account_page_router
from app.api.finance import router as finance_router
from app.api.jobs import router as jobs_router
from app.api.bookings import router as bookings_router
from app.api.payouts import router as payouts_router
from app.api.rewards import router as rewards_router
from app.core.config import settings
from app.core.logging import configure_logging
from app.core.rate_limit import _rate_limit_exceeded_handler, limiter

configure_logging()
logger = logging.getLogger(__name__)

# Off without a DSN (local dev, tests). Errors only, no performance tracing,
# to stay in Sentry's free tier. Sentry's logging integration sends every
# logger.exception() as an event, which covers the unhandled-exception
# catch in log_requests below — FastAPI never sees those exceptions itself.
if settings.sentry_dsn:
    sentry_sdk.init(dsn=settings.sentry_dsn)

app = FastAPI(title="Barbershop API")
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


# Added last so it's outermost: a browser's preflight request is answered
# here, before rate limiting or logging. The phone app isn't a browser and
# never needs this.
if settings.web_app_url:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[settings.web_app_url],
        allow_methods=["*"],
        allow_headers=["Authorization", "Content-Type"],
    )


app.include_router(bookings_router)
app.include_router(rewards_router)
app.include_router(payouts_router)
app.include_router(billing_router)
app.include_router(finance_router)
app.include_router(admin_router)
app.include_router(account_router)
app.include_router(auth_bridge_router)
app.include_router(billing_return_router)
app.include_router(delete_account_page_router)
app.include_router(jobs_router)


@app.get("/health")
@limiter.exempt
def health(request: Request) -> dict[str, str]:
    return {"status": "ok"}
