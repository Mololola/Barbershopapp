import datetime

from app.services.availability import compute_available_slots

UTC = datetime.UTC


def test_closed_day_has_no_slots():
    slots = compute_available_slots(
        date=datetime.date(2026, 7, 27),
        open_time=None,
        close_time=None,
        is_closed=True,
        duration_minutes=45,
        booked_ranges=[],
        now=datetime.datetime(2026, 7, 20, tzinfo=UTC),
    )
    assert slots == []


def test_slices_open_hours_into_duration_sized_slots():
    slots = compute_available_slots(
        date=datetime.date(2026, 7, 27),
        open_time=datetime.time(9, 0),
        close_time=datetime.time(10, 30),
        is_closed=False,
        duration_minutes=45,
        booked_ranges=[],
        now=datetime.datetime(2026, 7, 20, tzinfo=UTC),
    )
    assert slots == [
        datetime.datetime(2026, 7, 27, 9, 0, tzinfo=UTC),
        datetime.datetime(2026, 7, 27, 9, 45, tzinfo=UTC),
    ]


def test_excludes_slots_overlapping_an_existing_booking():
    booked = [
        (
            datetime.datetime(2026, 7, 27, 9, 45, tzinfo=UTC),
            datetime.datetime(2026, 7, 27, 10, 30, tzinfo=UTC),
        )
    ]
    slots = compute_available_slots(
        date=datetime.date(2026, 7, 27),
        open_time=datetime.time(9, 0),
        close_time=datetime.time(10, 30),
        is_closed=False,
        duration_minutes=45,
        booked_ranges=booked,
        now=datetime.datetime(2026, 7, 20, tzinfo=UTC),
    )
    assert slots == [datetime.datetime(2026, 7, 27, 9, 0, tzinfo=UTC)]


def test_excludes_slots_already_in_the_past():
    slots = compute_available_slots(
        date=datetime.date(2026, 7, 27),
        open_time=datetime.time(9, 0),
        close_time=datetime.time(11, 0),
        is_closed=False,
        duration_minutes=60,
        booked_ranges=[],
        now=datetime.datetime(2026, 7, 27, 9, 30, tzinfo=UTC),
    )
    assert slots == [datetime.datetime(2026, 7, 27, 10, 0, tzinfo=UTC)]
