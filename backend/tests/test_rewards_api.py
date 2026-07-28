import datetime

from app.api.rewards import _month_start, _tier_amount_cents


def test_automatic_tier_is_two_dollars():
    assert _tier_amount_cents(is_quality_reviewer=False) == 200


def test_quality_tier_replaces_automatic_with_three_dollars():
    assert _tier_amount_cents(is_quality_reviewer=True) == 300


def test_month_start_truncates_to_first_of_month_midnight():
    now = datetime.datetime(2026, 7, 27, 14, 32, 9, tzinfo=datetime.UTC)

    assert _month_start(now) == datetime.datetime(2026, 7, 1, tzinfo=datetime.UTC)


def test_month_start_handles_first_of_month():
    now = datetime.datetime(2026, 3, 1, 0, 0, 1, tzinfo=datetime.UTC)

    assert _month_start(now) == datetime.datetime(2026, 3, 1, tzinfo=datetime.UTC)
