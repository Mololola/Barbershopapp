from datetime import datetime, timezone

from app.api.billing import _add_one_calendar_month, _price_from_average


def test_price_is_ten_times_the_average_active_service_price():
    assert _price_from_average(2000) == 20000


def test_price_rounds_to_the_nearest_cent():
    assert _price_from_average(1033.4) == 10334


def test_no_active_services_returns_none():
    assert _price_from_average(None) is None


def test_add_one_calendar_month_same_day_next_month():
    start = datetime(2026, 1, 1, tzinfo=timezone.utc)
    assert _add_one_calendar_month(start) == datetime(2026, 2, 1, tzinfo=timezone.utc)


def test_add_one_calendar_month_mid_month():
    start = datetime(2026, 4, 15, tzinfo=timezone.utc)
    assert _add_one_calendar_month(start) == datetime(2026, 5, 15, tzinfo=timezone.utc)


def test_add_one_calendar_month_clamps_to_shorter_month():
    start = datetime(2026, 1, 31, tzinfo=timezone.utc)
    assert _add_one_calendar_month(start) == datetime(2026, 2, 28, tzinfo=timezone.utc)


def test_add_one_calendar_month_rolls_over_year():
    start = datetime(2026, 12, 15, tzinfo=timezone.utc)
    assert _add_one_calendar_month(start) == datetime(2027, 1, 15, tzinfo=timezone.utc)
