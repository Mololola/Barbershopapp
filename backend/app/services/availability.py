import datetime

BookedRange = tuple[datetime.datetime, datetime.datetime]


def _overlaps(start: datetime.datetime, end: datetime.datetime, booked_ranges: list[BookedRange]) -> bool:
    return any(start < booked_end and end > booked_start for booked_start, booked_end in booked_ranges)


def compute_available_slots(
    *,
    date: datetime.date,
    open_time: datetime.time | None,
    close_time: datetime.time | None,
    is_closed: bool,
    duration_minutes: int,
    booked_ranges: list[BookedRange],
    now: datetime.datetime,
) -> list[datetime.datetime]:
    """Candidate start times for a service on one day, sliced in
    duration-sized increments from opening time, minus already-booked ranges
    and anything in the past.

    This is advisory/UX only — the real "never double-book a worker"
    guarantee is the database's exclusion constraint (see
    docs/architecture.md), not this function.
    """
    if is_closed or open_time is None or close_time is None:
        return []

    tz = now.tzinfo
    slot_start = datetime.datetime.combine(date, open_time, tzinfo=tz)
    closing = datetime.datetime.combine(date, close_time, tzinfo=tz)
    duration = datetime.timedelta(minutes=duration_minutes)

    slots: list[datetime.datetime] = []
    while slot_start + duration <= closing:
        slot_end = slot_start + duration
        if slot_start >= now and not _overlaps(slot_start, slot_end, booked_ranges):
            slots.append(slot_start)
        slot_start += duration

    return slots
