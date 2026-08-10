import jwt
from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse
from limits import parse
from limits.strategies import MovingWindowRateLimiter
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

_TOO_MANY_REQUESTS_MESSAGE = "Too many requests — please try again shortly."


def _rate_limit_key(request: Request) -> str:
    """Buckets by authenticated user id when a bearer token is present,
    else falls back to client IP. Decoded without signature verification —
    this only ever picks a rate-limit bucket, never authorizes anything
    (get_current_user_id still does the real verification per route), so a
    forged or expired token just lands in its own harmless bucket instead
    of costing a JWKS round-trip on every single request."""
    auth_header = request.headers.get("authorization", "")
    if auth_header.lower().startswith("bearer "):
        try:
            payload = jwt.decode(auth_header[7:], options={"verify_signature": False})
            if sub := payload.get("sub"):
                return f"user:{sub}"
        except jwt.PyJWTError:
            pass
    return get_remote_address(request)


def _rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    # Matches every other error response's shape in this API (FastAPI's
    # HTTPException produces {"detail": ...}) so ApiClient._decode on the
    # mobile side surfaces a real message instead of slowapi's default
    # {"error": ...} body.
    return JSONResponse(status_code=429, content={"detail": _TOO_MANY_REQUESTS_MESSAGE})


# In-memory storage — fine for the current single `uvicorn --reload`
# process (same caveat as the scheduler in app/main.py). Pass a Redis
# storage_uri here if this ever runs as more than one process, since each
# process would otherwise track its own separate counters.
#
# Only used for: (1) the global default_limits below, enforced by
# SlowAPIMiddleware for every route that doesn't override it, and (2)
# @limiter.exempt on routes (like /health) that should never be checked at
# all. Do NOT use @limiter.limit(...) for a per-route override — see
# rate_limit() below for why.
limiter = Limiter(key_func=_rate_limit_key, default_limits=["60/minute"])

_strategy = MovingWindowRateLimiter(limiter._storage)


def rate_limit(limit_string: str):
    """A plain FastAPI dependency for overriding the default limit on one
    route — deliberately NOT slowapi's usual @limiter.limit decorator.

    That decorator wraps the endpoint function itself, and FastAPI only
    calls it after every Depends() on the route has already resolved. On
    any route that also depends on get_current_user_id, a request with no
    (or an invalid) token gets rejected with 401 during dependency
    resolution — before the decorator's check code ever runs — so
    @limiter.limit silently provides *zero* protection against a pure
    unauthenticated flood on that route (verified: it protects correctly
    once auth succeeds, and the middleware's own default_limits protects
    undecorated routes even when their auth fails — it's specifically
    "decorated route + failing dependency" that falls through both).

    Declaring this as the *first* dependency instead makes the check run
    before auth resolution, protecting every request, not just
    successfully-authenticated ones. Shares the same storage as `limiter`
    above, so counts stay consistent with the global default.
    """
    item = parse(limit_string)

    def check(request: Request) -> None:
        if not _strategy.hit(item, _rate_limit_key(request)):
            raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, _TOO_MANY_REQUESTS_MESSAGE)

    return check
