import datetime
from zoneinfo import ZoneInfo

from app.services.availability import compute_available_slots, working_periods

UTC = datetime.UTC
LONDON = ZoneInfo("Europe/London")
MADRID = ZoneInfo("Europe/Madrid")
DAY = datetime.date(2026, 7, 27)


def _hours(open_time, close_time, break_start=None, break_end=None):
    return {
        "is_closed": False,
        "open_time": open_time,
        "close_time": close_time,
        "break_start": break_start,
        "break_end": break_end,
    }


def test_closed_day_has_no_working_periods():
    closed = {"is_closed": True, "open_time": None, "close_time": None, "break_start": None, "break_end": None}

    assert working_periods(DAY, closed, UTC) == []


def test_break_splits_the_day_into_two_periods():
    hours = _hours(datetime.time(9, 0), datetime.time(20, 0), datetime.time(13, 30), datetime.time(16, 0))

    assert working_periods(DAY, hours, UTC) == [
        (datetime.datetime(2026, 7, 27, 9, 0, tzinfo=UTC), datetime.datetime(2026, 7, 27, 13, 30, tzinfo=UTC)),
        (datetime.datetime(2026, 7, 27, 16, 0, tzinfo=UTC), datetime.datetime(2026, 7, 27, 20, 0, tzinfo=UTC)),
    ]


def test_hours_are_wall_clock_time_in_the_shops_zone():
    hours = _hours(datetime.time(9, 0), datetime.time(18, 0))

    # British Summer Time / Spanish summer time: 09:00 local is 08:00 / 07:00 UTC.
    [(london_open, _)] = working_periods(DAY, hours, LONDON)
    [(madrid_open, _)] = working_periods(DAY, hours, MADRID)
    assert london_open == datetime.datetime(2026, 7, 27, 8, 0, tzinfo=UTC)
    assert madrid_open == datetime.datetime(2026, 7, 27, 7, 0, tzinfo=UTC)

    # In winter London is on UTC.
    [(winter_open, _)] = working_periods(datetime.date(2026, 1, 12), hours, LONDON)
    assert winter_open == datetime.datetime(2026, 1, 12, 9, 0, tzinfo=UTC)


def test_offers_every_quarter_hour_where_the_whole_service_fits_before_closing():
    slots = compute_available_slots(
        periods=working_periods(DAY, _hours(datetime.time(9, 0), datetime.time(10, 30)), UTC),
        duration_minutes=45,
        booked_ranges=[],
        now=datetime.datetime(2026, 7, 20, tzinfo=UTC),
    )
    # 9:45 is the last start that still ends by 10:30 closing.
    assert slots == [
        datetime.datetime(2026, 7, 27, 9, 0, tzinfo=UTC),
        datetime.datetime(2026, 7, 27, 9, 15, tzinfo=UTC),
        datetime.datetime(2026, 7, 27, 9, 30, tzinfo=UTC),
        datetime.datetime(2026, 7, 27, 9, 45, tzinfo=UTC),
    ]


def test_no_slot_overlaps_the_break_and_the_afternoon_restarts_at_its_end():
    hours = _hours(datetime.time(9, 0), datetime.time(12, 0), datetime.time(10, 0), datetime.time(11, 0))
    slots = compute_available_slots(
        periods=working_periods(DAY, hours, UTC),
        duration_minutes=45,
        booked_ranges=[],
        now=datetime.datetime(2026, 7, 20, tzinfo=UTC),
    )
    # Nothing after 9:15 fits before the 10:00 break; the afternoon
    # restarts at the break's end.
    assert slots == [
        datetime.datetime(2026, 7, 27, 9, 0, tzinfo=UTC),
        datetime.datetime(2026, 7, 27, 9, 15, tzinfo=UTC),
        datetime.datetime(2026, 7, 27, 11, 0, tzinfo=UTC),
        datetime.datetime(2026, 7, 27, 11, 15, tzinfo=UTC),
    ]


def test_excludes_slots_overlapping_an_existing_booking():
    booked = [
        (
            datetime.datetime(2026, 7, 27, 9, 45, tzinfo=UTC),
            datetime.datetime(2026, 7, 27, 10, 30, tzinfo=UTC),
        )
    ]
    slots = compute_available_slots(
        periods=working_periods(DAY, _hours(datetime.time(9, 0), datetime.time(10, 30)), UTC),
        duration_minutes=45,
        booked_ranges=booked,
        now=datetime.datetime(2026, 7, 20, tzinfo=UTC),
    )
    # Booked 9:45-10:30: only 9:00 ends (9:45) before that booking starts.
    assert slots == [datetime.datetime(2026, 7, 27, 9, 0, tzinfo=UTC)]


def test_a_start_right_after_an_existing_booking_is_offered():
    booked = [(datetime.datetime(2026, 7, 27, 9, 0, tzinfo=UTC), datetime.datetime(2026, 7, 27, 9, 30, tzinfo=UTC))]
    slots = compute_available_slots(
        periods=working_periods(DAY, _hours(datetime.time(9, 0), datetime.time(10, 30)), UTC),
        duration_minutes=45,
        booked_ranges=booked,
        now=datetime.datetime(2026, 7, 20, tzinfo=UTC),
    )
    assert slots == [
        datetime.datetime(2026, 7, 27, 9, 30, tzinfo=UTC),
        datetime.datetime(2026, 7, 27, 9, 45, tzinfo=UTC),
    ]


def test_excludes_slots_already_in_the_past():
    slots = compute_available_slots(
        periods=working_periods(DAY, _hours(datetime.time(9, 0), datetime.time(11, 0)), UTC),
        duration_minutes=60,
        booked_ranges=[],
        now=datetime.datetime(2026, 7, 27, 9, 30, tzinfo=UTC),
    )
    assert slots == [datetime.datetime(2026, 7, 27, 9, 30, tzinfo=UTC), datetime.datetime(2026, 7, 27, 9, 45, tzinfo=UTC),
                     datetime.datetime(2026, 7, 27, 10, 0, tzinfo=UTC)]
