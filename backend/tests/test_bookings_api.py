import psycopg
from fastapi import status
from sqlalchemy.exc import IntegrityError

from app.api.bookings import _map_booking_integrity_error


def test_exclusion_violation_maps_to_409():
    exc = IntegrityError("insert", {}, psycopg.errors.ExclusionViolation("conflicting key value"))

    mapped = _map_booking_integrity_error(exc)

    assert mapped.status_code == status.HTTP_409_CONFLICT


def test_other_integrity_error_maps_to_400():
    exc = IntegrityError("insert", {}, psycopg.errors.ForeignKeyViolation("not present"))

    mapped = _map_booking_integrity_error(exc)

    assert mapped.status_code == status.HTTP_400_BAD_REQUEST
