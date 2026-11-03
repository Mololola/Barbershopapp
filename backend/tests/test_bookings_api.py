import datetime
import uuid
from zoneinfo import ZoneInfo

import psycopg
import pytest
from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError

from app.api import bookings as bookings_api
from app.api.bookings import (
    _effective_hours,
    _map_booking_integrity_error,
    _slot_rejection_reason,
    complete_booking,
    mark_no_show,
    my_bookings_at_risk,
)
from app.models.booking import Booking


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

    assert _slot_rejection_reason(start, end, _OPEN_HOURS, _NOW, datetime.UTC) == "Cannot book a time in the past"


def test_slot_within_open_hours_is_accepted():
    start = datetime.datetime(2026, 7, 27, 10, 0, tzinfo=datetime.UTC)
    end = start + datetime.timedelta(minutes=30)

    assert _slot_rejection_reason(start, end, _OPEN_HOURS, _NOW, datetime.UTC) is None


def test_slot_before_opening_is_rejected():
    start = datetime.datetime(2026, 7, 27, 8, 30, tzinfo=datetime.UTC)
    end = start + datetime.timedelta(minutes=30)

    assert _slot_rejection_reason(start, end, _OPEN_HOURS, _NOW, datetime.UTC) == "Outside business hours"


def test_slot_ending_after_closing_is_rejected():
    start = datetime.datetime(2026, 7, 27, 17, 45, tzinfo=datetime.UTC)
    end = start + datetime.timedelta(minutes=30)

    assert _slot_rejection_reason(start, end, _OPEN_HOURS, _NOW, datetime.UTC) == "Outside business hours"


def test_slot_on_a_closed_day_is_rejected():
    closed = {"is_closed": True, "open_time": None, "close_time": None}
    start = datetime.datetime(2026, 7, 27, 10, 0, tzinfo=datetime.UTC)
    end = start + datetime.timedelta(minutes=30)

    assert _slot_rejection_reason(start, end, closed, _NOW, datetime.UTC) == "Outside business hours"


def test_slot_inside_a_break_is_rejected():
    with_break = {**_OPEN_HOURS, "break_start": datetime.time(13, 0), "break_end": datetime.time(14, 0)}
    start = datetime.datetime(2026, 7, 27, 12, 45, tzinfo=datetime.UTC)
    end = start + datetime.timedelta(minutes=30)

    assert _slot_rejection_reason(start, end, with_break, _NOW, datetime.UTC) == "Outside business hours"


def test_slot_after_a_break_is_accepted():
    with_break = {**_OPEN_HOURS, "break_start": datetime.time(13, 0), "break_end": datetime.time(14, 0)}
    start = datetime.datetime(2026, 7, 27, 14, 0, tzinfo=datetime.UTC)
    end = start + datetime.timedelta(minutes=30)

    assert _slot_rejection_reason(start, end, with_break, _NOW, datetime.UTC) is None


def test_opening_hours_are_checked_in_the_shops_local_time():
    london = ZoneInfo("Europe/London")
    # 08:00 UTC is 09:00 in London in July: opening time, so bookable.
    start = datetime.datetime(2026, 7, 27, 8, 0, tzinfo=datetime.UTC)
    end = start + datetime.timedelta(minutes=30)
    now = datetime.datetime(2026, 7, 27, 6, 0, tzinfo=datetime.UTC)

    assert _slot_rejection_reason(start, end, _OPEN_HOURS, now, london) is None
    # 17:45 UTC is 18:45 in London — after closing.
    late = datetime.datetime(2026, 7, 27, 17, 45, tzinfo=datetime.UTC)
    assert _slot_rejection_reason(late, late + datetime.timedelta(minutes=30), _OPEN_HOURS, now, london) == (
        "Outside business hours"
    )


def test_bookings_at_risk_use_the_grace_period_and_30_day_notice():
    booking_id = uuid.uuid4()
    cancelled_at = datetime.datetime(2026, 4, 2, tzinfo=datetime.UTC)

    class _Db:
        def execute(self, statement, params):
            self.params = params
            return self

        def mappings(self):
            return [{"booking_id": booking_id, "cancelled_at": cancelled_at}]

    db = _Db()
    result = my_bookings_at_risk(db=db, user_id="me")

    assert db.params == {"user_id": "me", "days": 60, "notice_days": 30}
    assert [(r.booking_id, r.cancelled_at) for r in result] == [(booking_id, cancelled_at)]


class _CommitDb:
    def commit(self):
        pass

    def refresh(self, booking):
        pass


def _owned_booking(monkeypatch, start_time):
    booking = Booking(id=uuid.uuid4(), business_id=uuid.uuid4(), status="confirmed", start_time=start_time)
    monkeypatch.setattr(bookings_api, "_get_booking_or_404", lambda db, booking_id: booking)
    monkeypatch.setattr(bookings_api, "_is_business_owner", lambda db, business_id, user_id: True)
    return booking


def test_a_booking_cant_be_marked_done_before_it_starts(monkeypatch):
    booking = _owned_booking(monkeypatch, datetime.datetime.now(datetime.UTC) + datetime.timedelta(hours=1))

    with pytest.raises(HTTPException) as exc:
        complete_booking(booking.id, db=_CommitDb(), user_id="owner")

    assert exc.value.status_code == status.HTTP_400_BAD_REQUEST
    assert booking.status == "confirmed"


def test_a_booking_that_has_started_can_be_marked_done(monkeypatch):
    booking = _owned_booking(monkeypatch, datetime.datetime.now(datetime.UTC) - datetime.timedelta(minutes=5))

    complete_booking(booking.id, db=_CommitDb(), user_id="owner")

    assert booking.status == "completed"
    assert booking.completed_at is not None


def test_a_booking_cant_be_a_no_show_before_it_starts(monkeypatch):
    booking = _owned_booking(monkeypatch, datetime.datetime.now(datetime.UTC) + datetime.timedelta(hours=1))

    with pytest.raises(HTTPException) as exc:
        mark_no_show(booking.id, db=_CommitDb(), user_id="owner")

    assert exc.value.status_code == status.HTTP_400_BAD_REQUEST
    assert booking.status == "confirmed"


def test_a_started_booking_can_be_marked_a_no_show(monkeypatch):
    booking = _owned_booking(monkeypatch, datetime.datetime.now(datetime.UTC) - datetime.timedelta(minutes=5))

    mark_no_show(booking.id, db=_CommitDb(), user_id="owner")

    assert booking.status == "no_show"
    assert booking.completed_at is None


class _ReviewsDb(_CommitDb):
    def __init__(self, reviewed=False):
        self.reviewed = reviewed

    def execute(self, *args):
        reviewed = self.reviewed

        class _Result:
            def first(self):
                return (1,) if reviewed else None

        return _Result()


def _auto_completed_booking(monkeypatch, completed_ago):
    now = datetime.datetime.now(datetime.UTC)
    booking = _owned_booking(monkeypatch, now - completed_ago - datetime.timedelta(hours=3))
    booking.status = "completed"
    booking.auto_completed = True
    booking.completed_at = now - completed_ago
    return booking


def test_an_auto_completed_booking_can_become_a_no_show_within_7_days(monkeypatch):
    booking = _auto_completed_booking(monkeypatch, datetime.timedelta(days=6))

    mark_no_show(booking.id, db=_ReviewsDb(), user_id="owner")

    assert booking.status == "no_show"
    assert booking.completed_at is None
    assert booking.auto_completed is False


def test_not_after_7_days(monkeypatch):
    booking = _auto_completed_booking(monkeypatch, datetime.timedelta(days=8))

    with pytest.raises(HTTPException):
        mark_no_show(booking.id, db=_ReviewsDb(), user_id="owner")

    assert booking.status == "completed"


def test_not_once_the_customer_has_reviewed_it(monkeypatch):
    booking = _auto_completed_booking(monkeypatch, datetime.timedelta(days=1))

    with pytest.raises(HTTPException):
        mark_no_show(booking.id, db=_ReviewsDb(reviewed=True), user_id="owner")

    assert booking.status == "completed"


def test_a_booking_the_shop_marked_done_itself_cant_become_a_no_show(monkeypatch):
    booking = _auto_completed_booking(monkeypatch, datetime.timedelta(days=1))
    booking.auto_completed = False

    with pytest.raises(HTTPException):
        mark_no_show(booking.id, db=_ReviewsDb(), user_id="owner")


def test_confirming_an_auto_completed_booking_keeps_it_done_and_stops_asking(monkeypatch):
    booking = _auto_completed_booking(monkeypatch, datetime.timedelta(days=1))
    completed_at = booking.completed_at

    complete_booking(booking.id, db=_ReviewsDb(), user_id="owner")

    assert booking.status == "completed"
    assert booking.auto_completed is False
    assert booking.completed_at == completed_at
