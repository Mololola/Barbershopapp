from app.core.cache import Cache


def test_returns_freshly_fetched_value_on_first_call():
    cache = Cache(maxsize=10, ttl_seconds=60)

    assert cache.get_or_set("k", lambda: "fresh") == "fresh"


def test_second_call_uses_the_cached_value_without_calling_fetch_again():
    cache = Cache(maxsize=10, ttl_seconds=60)
    calls = []

    def fetch():
        calls.append(1)
        return "value"

    cache.get_or_set("k", fetch)
    cache.get_or_set("k", fetch)

    assert len(calls) == 1


def test_different_keys_are_cached_independently():
    cache = Cache(maxsize=10, ttl_seconds=60)

    assert cache.get_or_set("a", lambda: 1) == 1
    assert cache.get_or_set("b", lambda: 2) == 2


def test_none_is_a_valid_cached_value_not_treated_as_a_miss():
    cache = Cache(maxsize=10, ttl_seconds=60)
    calls = []

    def fetch():
        calls.append(1)
        return None

    assert cache.get_or_set("k", fetch) is None
    assert cache.get_or_set("k", fetch) is None
    assert len(calls) == 1


def test_falls_back_to_fetch_when_the_cache_read_itself_fails():
    cache = Cache(maxsize=10, ttl_seconds=60)

    class BrokenStore:
        def __contains__(self, key):
            raise RuntimeError("cache backend is down")

    cache._store = BrokenStore()

    assert cache.get_or_set("k", lambda: "fresh") == "fresh"


def test_falls_back_gracefully_when_the_cache_write_itself_fails():
    cache = Cache(maxsize=10, ttl_seconds=60)

    class WriteBrokenStore(dict):
        def __setitem__(self, key, value):
            raise RuntimeError("cache backend is down")

    cache._store = WriteBrokenStore()

    # Must not raise, and must still return the freshly fetched value even
    # though caching it failed.
    assert cache.get_or_set("k", lambda: "fresh") == "fresh"
