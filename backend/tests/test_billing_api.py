from datetime import datetime, timedelta, timezone

from app.api.billing import _price_from_average, _trial_end_timestamp


def test_price_is_ten_times_the_average_active_service_price():
    assert _price_from_average(2000) == 20000


def test_price_rounds_to_the_nearest_cent():
    assert _price_from_average(1033.4) == 10334


def test_no_active_services_returns_none():
    assert _price_from_average(None) is None










def test_no_trial_grant_returns_none():
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    assert _trial_end_timestamp(None, now) is None


def test_trial_well_in_the_future_returns_its_unix_timestamp():
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    trial_ends_at = now + timedelta(days=30)
    assert _trial_end_timestamp(trial_ends_at, now) == int(trial_ends_at.timestamp())


def test_trial_less_than_48h_out_is_ignored_not_an_error():
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    trial_ends_at = now + timedelta(hours=10)
    assert _trial_end_timestamp(trial_ends_at, now) is None


def test_lapsed_trial_is_ignored():
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    trial_ends_at = now - timedelta(days=5)
    assert _trial_end_timestamp(trial_ends_at, now) is None


def test_trial_exactly_at_the_48h_boundary_is_accepted():
    # Stripe's own rule is "at least 48h" — exactly 48h should pass, not be
    # treated the same as too-close-to-now.
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    trial_ends_at = now + timedelta(hours=48)
    assert _trial_end_timestamp(trial_ends_at, now) == int(trial_ends_at.timestamp())
