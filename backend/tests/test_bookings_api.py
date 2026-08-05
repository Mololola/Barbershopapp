import datetime

import psycopg
from fastapi import status
from sqlalchemy.exc import IntegrityError

from app.api.bookings import _effective_hours, _map_booking_integrity_error, _slot_rejection_reason


def test_exclusion_violation_maps_to_409():
    exc = IntegrityError("insert", {}, psycopg.errors.ExclusionViolation("conflicting key value"))

    mapped = _map_booking_integrity_error(exc)

    assert mapped.status_code == status.HTTP_409_CONFLICT


def test_other_integrity_error_maps_to_400():
    exc = IntegrityError("insert", {}, psycopg.errors.ForeignKeyViolation("not present"))

    mapped = _map_booking_integrity_error(exc)

    assert mapped.status_code == status.HTTP_400_BAD_REQUEST


def test_worker_with_no_schedule_falls_back_to_business_hours():
    business_hours = {"is_closed": False, "open_time": datetime.time(9, 0), "close_time": datetime.time(18, 0)}

    assert _effective_hours(None, business_hours) == business_hours


def test_worker_with_own_schedule_overrides_business_hours_even_when_off():
    business_hours = {"is_closed": False, "open_time": datetime.time(9, 0), "close_time": datetime.time(18, 0)}
    worker_day_off = {"is_closed": True, "open_time": None, "close_time": None}

    assert _effective_hours(worker_day_off, business_hours) == worker_day_off


_OPEN_HOURS = {"is_closed": False, "open_time": datetime.time(9, 0), "close_time": datetime.time(18, 0)}
_NOW = datetime.datetime(2026, 7, 27, 8, 0, tzinfo=datetime.UTC)


def test_slot_in_the_past_is_rejected():
    start = _NOW - datetime.timedelta(hours=1)
    end = start + datetime.timedelta(minutes=30)

    assert _slot_rejection_reason(start, end, _OPEN_HOURS, _NOW) == "Cannot book a time in the past"


def test_slot_within_open_hours_is_accepted():
    start = datetime.datetime(2026, 7, 27, 10, 0, tzinfo=datetime.UTC)
    end = start + datetime.timedelta(minutes=30)

    assert _slot_rejection_reason(start, end, _OPEN_HOURS, _NOW) is None


def test_slot_before_opening_is_rejected():
    start = datetime.datetime(2026, 7, 27, 8, 30, tzinfo=datetime.UTC)
    end = start + datetime.timedelta(minutes=30)

    assert _slot_rejection_reason(start, end, _OPEN_HOURS, _NOW) == "Outside business hours"


def test_slot_ending_after_closing_is_rejected():
    start = datetime.datetime(2026, 7, 27, 17, 45, tzinfo=datetime.UTC)
    end = start + datetime.timedelta(minutes=30)

    assert _slot_rejection_reason(start, end, _OPEN_HOURS, _NOW) == "Outside business hours"


def test_slot_on_a_closed_day_is_rejected():
    closed = {"is_closed": True, "open_time": None, "close_time": None}
    start = datetime.datetime(2026, 7, 27, 10, 0, tzinfo=datetime.UTC)
    end = start + datetime.timedelta(minutes=30)

    assert _slot_rejection_reason(start, end, closed, _NOW) == "Outside business hours"
