import datetime

BookedRange = tuple[datetime.datetime, datetime.datetime]
Period = tuple[datetime.datetime, datetime.datetime]

# Customers can start a service at any quarter hour the barber is free for
# its whole length — not only on a grid of service-length blocks from
# opening. 15 is the industry norm: flexible without leaving unfillable
# few-minute gaps between bookings.
SLOT_STEP_MINUTES = 15


def _overlaps(start: datetime.datetime, end: datetime.datetime, booked_ranges: list[BookedRange]) -> bool:
    return any(start < booked_end and end > booked_start for booked_start, booked_end in booked_ranges)


def working_periods(date: datetime.date, hours: dict, tz: datetime.tzinfo) -> list[Period]:
    """The bookable stretches of one day, as aware datetimes. Hours are
    wall-clock times in the shop's own zone (`tz`), so a 09:00 opening is
    09:00 there whatever the season. An optional break splits the day in
    two; a closed day has none."""
    if hours["is_closed"] or hours["open_time"] is None or hours["close_time"] is None:
        return []

    def at(time: datetime.time) -> datetime.datetime:
        return datetime.datetime.combine(date, time, tzinfo=tz)

    if hours.get("break_start") is None or hours.get("break_end") is None:
        return [(at(hours["open_time"]), at(hours["close_time"]))]
    return [
        (at(hours["open_time"]), at(hours["break_start"])),
        (at(hours["break_end"]), at(hours["close_time"])),
    ]


def compute_available_slots(
    *,
    periods: list[Period],
    duration_minutes: int,
    booked_ranges: list[BookedRange],
    now: datetime.datetime,
) -> list[datetime.datetime]:
    """Candidate start times for a service on one day: every
    SLOT_STEP_MINUTES from the start of each working period (so the
    afternoon after a break starts on the break's end) where the whole
    service fits before the period ends and overlaps no existing booking,
    minus anything in the past.

    This is advisory/UX only — the real "never double-book a worker"
    guarantee is the database's exclusion constraint (see
    docs/architecture.md), not this function.
    """
    duration = datetime.timedelta(minutes=duration_minutes)
    step = datetime.timedelta(minutes=SLOT_STEP_MINUTES)

    slots: list[datetime.datetime] = []
    for period_start, period_end in periods:
        slot_start = period_start
        while slot_start + duration <= period_end:
            slot_end = slot_start + duration
            if slot_start >= now and not _overlaps(slot_start, slot_end, booked_ranges):
                slots.append(slot_start)
            slot_start += step

    return slots
