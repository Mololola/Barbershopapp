import datetime

import psycopg
from fastapi import status
from sqlalchemy.exc import IntegrityError

from app.api.bookings import _effective_hours, _map_booking_integrity_error


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
