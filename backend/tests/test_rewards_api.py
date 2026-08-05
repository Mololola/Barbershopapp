import datetime

import psycopg
from sqlalchemy.exc import IntegrityError

from app.api.rewards import _is_duplicate_reward_error, _month_start, _tier_amount_cents


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


def test_review_id_unique_violation_is_a_duplicate_reward():
    exc = IntegrityError("insert", {}, psycopg.errors.UniqueViolation("duplicate key value"))

    assert _is_duplicate_reward_error(exc) is True


def test_other_integrity_error_is_not_a_duplicate_reward():
    exc = IntegrityError("insert", {}, psycopg.errors.ForeignKeyViolation("not present"))

    assert _is_duplicate_reward_error(exc) is False
