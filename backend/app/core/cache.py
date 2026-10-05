import logging
import threading
from typing import Callable, TypeVar

from cachetools import TTLCache

from app.core.config import settings

logger = logging.getLogger(__name__)

T = TypeVar("T")


class Cache:
    """A small, swappable wrapper around an in-process TTL cache.

    In-process only — correct today because this app runs as a single
    `uvicorn` process (same assumption already documented for the
    rate limiter in app/core/rate_limit.py and the connection pool in
    app/db/session.py). If this ever runs as more than one process or
    replica, each would keep its own separate cache and could show a
    different, independently-stale view for up to `ttl_seconds` after a
    write — nothing here would be *wrong*, since every entry still expires
    and self-corrects, but two users hitting two different instances could
    briefly disagree. Swapping `_store` for a shared backend (e.g. Redis)
    would fix that; get_or_set()'s call sites don't need to change, only
    what's inside this class does.

    Thread-safe: FastAPI runs sync route handlers (the ones using this) in
    a thread pool, so concurrent requests really can hit this
    simultaneously, not just theoretically. A single lock is enough at
    this scale — the DB round-trip this saves costs far more than any lock
    contention it could cause. Not solved: a "thundering herd" of
    concurrent misses on the exact same cold key can each redundantly call
    `fetch()` once; the fetches here are cheap, safe, idempotent SELECTs,
    so that's an accepted tradeoff, not a bug.
    """

    def __init__(self, maxsize: int, ttl_seconds: int) -> None:
        self._store: TTLCache = TTLCache(maxsize=maxsize, ttl=ttl_seconds)
        self._lock = threading.Lock()

    def get_or_set(self, key: str, fetch: Callable[[], T]) -> T:
        """Returns the cached value for `key`, computing and storing it via
        `fetch()` on a miss. A failure reading or writing the cache itself
        (not `fetch()` failing — that's a real error and propagates
        normally) falls back to calling `fetch()` directly, so a broken
        cache degrades to "no caching" instead of a failed request.
        """
        try:
            with self._lock:
                if key in self._store:
                    return self._store[key]
        except Exception:
            logger.warning("Cache read failed for key %s — falling back to source", key, exc_info=True)
            return fetch()

        value = fetch()

        try:
            with self._lock:
                self._store[key] = value
        except Exception:
            logger.warning("Cache write failed for key %s — served from source, not cached", key, exc_info=True)

        return value


cache = Cache(maxsize=settings.cache_max_size, ttl_seconds=settings.cache_ttl_seconds)
