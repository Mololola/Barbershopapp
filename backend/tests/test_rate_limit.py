import pytest
from fastapi import HTTPException
from starlette.requests import Request

from app.core.rate_limit import rate_limit


def _fake_request(ip: str, authorization: str | None = None) -> Request:
    headers = [(b"authorization", authorization.encode())] if authorization else []
    return Request({"type": "http", "headers": headers, "client": (ip, 12345)})


def test_allows_requests_within_the_limit():
    check = rate_limit("2/minute")
    request = _fake_request("10.0.0.1")

    check(request)
    check(request)  # still within limit — must not raise


def test_rejects_requests_over_the_limit():
    check = rate_limit("2/minute")
    request = _fake_request("10.0.0.2")

    check(request)
    check(request)
    with pytest.raises(HTTPException) as exc_info:
        check(request)
    assert exc_info.value.status_code == 429


def test_buckets_are_independent_per_client_ip():
    check = rate_limit("1/minute")

    check(_fake_request("10.0.0.3"))  # uses up this client's one allowed request
    check(_fake_request("10.0.0.4"))  # a different client — must not raise
