from app.api.billing import _price_from_average


def test_price_is_ten_times_the_average_active_service_price():
    assert _price_from_average(2000) == 20000


def test_price_rounds_to_the_nearest_cent():
    assert _price_from_average(1033.4) == 10334


def test_no_active_services_returns_none():
    assert _price_from_average(None) is None
