"""The finance tool's numbers: the free monthly summary and the premium
analysis (forecast, history, utilisation, barbers, customers, suggestions).

Pure functions over plain data — no database — so every figure a business
may act on is exactly unit-testable. All calendar logic (months, weekdays,
hours) runs in the shop's own time zone.
"""

import dataclasses
import datetime
import math
import statistics

from app.services.availability import working_periods

UTC = datetime.UTC

# Premium windows. Long enough to smooth out one odd week, short enough to
# reflect how the shop runs now.
UTILISATION_WINDOW_DAYS = 56
SERVICE_WINDOW_DAYS = 90
RECENT_WINDOW_DAYS = 30
REGULAR_WINDOW_DAYS = 180

# Below this many completed bookings in the last 90 days, suggestions would
# be guesses dressed up as advice — none are made.
MIN_BOOKINGS_FOR_SUGGESTIONS = 10

_DAYS_PER_MONTH = 30.44
_WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


@dataclasses.dataclass(frozen=True)
class BookingRow:
    start: datetime.datetime
    end: datetime.datetime
    status: str
    price_cents: int
    worker_id: str
    service_id: str
    customer_id: str


@dataclasses.dataclass(frozen=True)
class CostRow:
    kind: str  # 'monthly' | 'one_off'
    amount_cents: int
    starts_on: datetime.date
    ends_on: datetime.date | None


@dataclasses.dataclass(frozen=True)
class ShopData:
    tz: datetime.tzinfo
    bookings: list[BookingRow]
    costs: list[CostRow]
    other_income: dict[datetime.date, int]  # first-of-month -> cents
    business_hours: dict[int, dict]  # weekday (Mon=0) -> hours row
    worker_names: dict[str, str]  # active workers only
    worker_schedules: dict[str, dict[int, dict]]  # worker -> weekday -> hours row
    service_names: dict[str, str]
    average_service_price_cents: int
    first_visit: dict[str, datetime.datetime]  # customer -> first completed visit, ever
    worker_ratings: dict[str, float]


# ---------------------------------------------------------------- helpers


def month_start(day: datetime.date) -> datetime.date:
    return day.replace(day=1)


def add_months(month: datetime.date, n: int) -> datetime.date:
    index = month.year * 12 + month.month - 1 + n
    return datetime.date(index // 12, index % 12 + 1, 1)


def _local_date(moment: datetime.datetime, tz: datetime.tzinfo) -> datetime.date:
    return moment.astimezone(tz).date()


def _completed(data: ShopData) -> list[BookingRow]:
    return [b for b in data.bookings if b.status == "completed"]


def _in_month(b: BookingRow, month: datetime.date, tz: datetime.tzinfo) -> bool:
    return month_start(_local_date(b.start, tz)) == month


def costs_for_month(costs: list[CostRow], month: datetime.date) -> int:
    """Monthly costs running that month, plus one-offs dated to it."""
    total = 0
    for cost in costs:
        if cost.kind == "one_off":
            if cost.starts_on == month:
                total += cost.amount_cents
        elif cost.starts_on <= month and (cost.ends_on is None or month <= cost.ends_on):
            total += cost.amount_cents
    return total


def _worker_hours(data: ShopData, worker_id: str, weekday: int) -> dict | None:
    """A worker's own schedule for the day wins over the shop's hours (same
    rule as booking availability)."""
    schedule = data.worker_schedules.get(worker_id, {}).get(weekday)
    return schedule if schedule is not None else data.business_hours.get(weekday)


def _overlap_minutes(a_start, a_end, b_start, b_end) -> float:
    return max(0.0, (min(a_end, b_end) - max(a_start, b_start)).total_seconds() / 60)


def _is_open(data: ShopData, day: datetime.date) -> bool:
    hours = data.business_hours.get(day.weekday())
    return bool(hours) and bool(working_periods(day, hours, data.tz))


# ------------------------------------------------------------------ free


@dataclasses.dataclass(frozen=True)
class MonthFigures:
    month: datetime.date
    booking_revenue_cents: int
    other_income_cents: int
    costs_cents: int
    completed_bookings: int

    @property
    def revenue_cents(self) -> int:
        return self.booking_revenue_cents + self.other_income_cents

    @property
    def net_cents(self) -> int:
        return self.revenue_cents - self.costs_cents


def month_figures(data: ShopData, month: datetime.date) -> MonthFigures:
    done = [b for b in _completed(data) if _in_month(b, month, data.tz)]
    return MonthFigures(
        month=month,
        booking_revenue_cents=sum(b.price_cents for b in done),
        other_income_cents=data.other_income.get(month, 0),
        costs_cents=costs_for_month(data.costs, month),
        completed_bookings=len(done),
    )


def average_ticket_cents(figures: MonthFigures, fallback_cents: int) -> int:
    if figures.completed_bookings == 0:
        return fallback_cents
    return round(figures.booking_revenue_cents / figures.completed_bookings)


def bookings_to_break_even(figures: MonthFigures, ticket_cents: int) -> int | None:
    """How many more bookings at the average price close the month's gap;
    None when already in profit (or there's no price to go on)."""
    if figures.net_cents >= 0 or ticket_cents <= 0:
        return None
    return math.ceil(-figures.net_cents / ticket_cents)


# --------------------------------------------------------------- forecast


@dataclasses.dataclass(frozen=True)
class Forecast:
    projected_revenue_cents: int
    projected_net_cents: int
    confirmed_upcoming_cents: int
    break_even_day: datetime.date | None
    already_broken_even: bool


def forecast_month(data: ShopData, month: datetime.date, now: datetime.datetime) -> Forecast:
    """This month's likely finish: completed revenue so far, plus the rest
    of the month at the pace set on open days so far — never less than
    what's already confirmed in the diary."""
    tz = data.tz
    today = _local_date(now, tz)
    next_month = add_months(month, 1)
    days = [month + datetime.timedelta(days=i) for i in range((next_month - month).days)]

    daily_revenue: dict[datetime.date, int] = {}
    for b in _completed(data):
        day = _local_date(b.start, tz)
        if month <= day < next_month:
            daily_revenue[day] = daily_revenue.get(day, 0) + b.price_cents
    confirmed_by_day: dict[datetime.date, int] = {}
    for b in data.bookings:
        day = _local_date(b.start, tz)
        if b.status == "confirmed" and b.start >= now and month <= day < next_month:
            confirmed_by_day[day] = confirmed_by_day.get(day, 0) + b.price_cents

    past_open = [d for d in days if d < today and _is_open(data, d)]
    earned_before_today = sum(v for d, v in daily_revenue.items() if d < today)
    pace = earned_before_today / len(past_open) if past_open else 0.0

    other_income = data.other_income.get(month, 0)
    costs = costs_for_month(data.costs, month)
    target = costs - other_income

    running = 0.0
    break_even_day = None
    already = False
    for day in days:
        if day < today:
            running += daily_revenue.get(day, 0)
        elif _is_open(data, day) or day in confirmed_by_day or day in daily_revenue:
            # Today and later: whichever is larger of what's already done or
            # booked for the day, and the usual pace.
            running += max(pace, daily_revenue.get(day, 0) + confirmed_by_day.get(day, 0))
        if break_even_day is None and running >= target and target > 0:
            break_even_day = day
            already = day < today
    if target <= 0:
        already = True

    projected_bookings = round(running)
    return Forecast(
        projected_revenue_cents=projected_bookings + other_income,
        projected_net_cents=projected_bookings + other_income - costs,
        confirmed_upcoming_cents=sum(confirmed_by_day.values()),
        break_even_day=break_even_day,
        already_broken_even=already,
    )


# ------------------------------------------------------------ utilisation


@dataclasses.dataclass(frozen=True)
class HeatCell:
    weekday: int
    hour: int
    available_minutes: float
    booked_minutes: float

    @property
    def utilisation(self) -> float | None:
        return self.booked_minutes / self.available_minutes if self.available_minutes else None


def utilisation_heatmap(data: ShopData, now: datetime.datetime) -> list[HeatCell]:
    """Chair time booked vs available, by weekday and hour, over the last
    8 weeks, across current staff."""
    tz = data.tz
    today = _local_date(now, tz)
    start_day = today - datetime.timedelta(days=UTILISATION_WINDOW_DAYS)
    available: dict[tuple[int, int], float] = {}
    booked: dict[tuple[int, int], float] = {}

    def spread(store, start, end):
        cursor = start.astimezone(tz).replace(minute=0, second=0, microsecond=0)
        while cursor < end:
            next_hour = cursor + datetime.timedelta(hours=1)
            minutes = _overlap_minutes(start, end, cursor, next_hour)
            if minutes:
                key = (cursor.weekday(), cursor.hour)
                store[key] = store.get(key, 0.0) + minutes
            cursor = next_hour

    for offset in range(UTILISATION_WINDOW_DAYS):
        day = start_day + datetime.timedelta(days=offset)
        for worker_id in data.worker_names:
            hours = _worker_hours(data, worker_id, day.weekday())
            if not hours:
                continue
            for period_start, period_end in working_periods(day, hours, tz):
                spread(available, period_start, period_end)

    window_start = datetime.datetime.combine(start_day, datetime.time.min, tzinfo=tz)
    window_end = datetime.datetime.combine(today, datetime.time.min, tzinfo=tz)
    for b in data.bookings:
        if b.status in ("confirmed", "completed") and b.worker_id in data.worker_names:
            if b.end > window_start and b.start < window_end:
                spread(booked, max(b.start, window_start), min(b.end, window_end))

    return [
        HeatCell(weekday=k[0], hour=k[1], available_minutes=v, booked_minutes=booked.get(k, 0.0))
        for k, v in sorted(available.items())
    ]


def overall_utilisation(cells: list[HeatCell]) -> float | None:
    available = sum(c.available_minutes for c in cells)
    return sum(c.booked_minutes for c in cells) / available if available else None


# ---------------------------------------------------------------- barbers


@dataclasses.dataclass(frozen=True)
class BarberStats:
    worker_id: str
    name: str
    bookings: int
    revenue_cents: int
    utilisation: float | None
    average_rating: float | None


def barber_stats(data: ShopData, now: datetime.datetime) -> list[BarberStats]:
    """Last 30 days, current staff, highest revenue first."""
    tz = data.tz
    since = now - datetime.timedelta(days=RECENT_WINDOW_DAYS)
    today = _local_date(now, tz)
    results = []
    for worker_id, name in data.worker_names.items():
        done = [b for b in _completed(data) if b.worker_id == worker_id and since <= b.start < now]
        available = 0.0
        for offset in range(1, RECENT_WINDOW_DAYS + 1):
            day = today - datetime.timedelta(days=offset)
            hours = _worker_hours(data, worker_id, day.weekday())
            if hours:
                available += sum(
                    (end - start).total_seconds() / 60 for start, end in working_periods(day, hours, tz)
                )
        booked = sum((b.end - b.start).total_seconds() / 60 for b in done)
        results.append(
            BarberStats(
                worker_id=worker_id,
                name=name,
                bookings=len(done),
                revenue_cents=sum(b.price_cents for b in done),
                utilisation=booked / available if available else None,
                average_rating=data.worker_ratings.get(worker_id),
            )
        )
    return sorted(results, key=lambda s: s.revenue_cents, reverse=True)


# --------------------------------------------------------------- services


@dataclasses.dataclass(frozen=True)
class ServiceStats:
    name: str
    bookings: int
    revenue_cents: int
    share: float
    previous_bookings: int


def service_stats(data: ShopData, now: datetime.datetime) -> list[ServiceStats]:
    """Last 90 days vs the 90 before, by revenue."""
    window = datetime.timedelta(days=SERVICE_WINDOW_DAYS)
    recent = [b for b in _completed(data) if now - window <= b.start < now]
    previous = [b for b in _completed(data) if now - 2 * window <= b.start < now - window]
    total = len(recent)
    ids = {b.service_id for b in recent} | {b.service_id for b in previous}
    stats = []
    for service_id in ids:
        mine = [b for b in recent if b.service_id == service_id]
        stats.append(
            ServiceStats(
                name=data.service_names.get(service_id, "Other services"),
                bookings=len(mine),
                revenue_cents=sum(b.price_cents for b in mine),
                share=len(mine) / total if total else 0.0,
                previous_bookings=sum(1 for b in previous if b.service_id == service_id),
            )
        )
    return sorted(stats, key=lambda s: s.revenue_cents, reverse=True)


# -------------------------------------------------------------- customers


@dataclasses.dataclass(frozen=True)
class AtRiskCustomer:
    customer_id: str
    visits: int
    last_visit: datetime.date
    usual_gap_days: int
    days_since: int


@dataclasses.dataclass(frozen=True)
class CustomerStats:
    customers_last_30_days: int
    new_last_30_days: int
    returning_last_30_days: int
    return_rate: float | None  # of customers seen 6-12 weeks ago, share back since
    at_risk: list[AtRiskCustomer]


def customer_stats(data: ShopData, now: datetime.datetime) -> CustomerStats:
    tz = data.tz
    done = sorted(_completed(data), key=lambda b: b.start)
    recent_since = now - datetime.timedelta(days=RECENT_WINDOW_DAYS)
    recent_customers = {b.customer_id for b in done if recent_since <= b.start < now}
    new = {c for c in recent_customers if data.first_visit.get(c, now) >= recent_since}

    cohort_from, cohort_to = now - datetime.timedelta(days=84), now - datetime.timedelta(days=42)
    cohort: dict[str, datetime.datetime] = {}
    for b in done:
        if cohort_from <= b.start < cohort_to:
            cohort[b.customer_id] = max(cohort.get(b.customer_id, b.start), b.start)
    came_back = sum(1 for c, seen in cohort.items() if any(b.customer_id == c and b.start > seen for b in done))

    visits_by_customer: dict[str, list[datetime.datetime]] = {}
    for b in done:
        if b.start >= now - datetime.timedelta(days=REGULAR_WINDOW_DAYS):
            visits_by_customer.setdefault(b.customer_id, []).append(b.start)
    at_risk = []
    for customer_id, visits in visits_by_customer.items():
        if len(visits) < 3:
            continue
        gaps = [(b - a).days for a, b in zip(visits, visits[1:])]
        usual = statistics.median(gaps)
        days_since = (now - visits[-1]).days
        # Overdue by half as long again as their usual gap, and at least five
        # weeks — a regular on a monthly cycle a few days late isn't lost.
        if days_since > max(1.5 * usual, 35):
            at_risk.append(
                AtRiskCustomer(
                    customer_id=customer_id,
                    visits=len(visits),
                    last_visit=_local_date(visits[-1], tz),
                    usual_gap_days=round(usual),
                    days_since=days_since,
                )
            )
    at_risk.sort(key=lambda c: (c.visits, c.days_since), reverse=True)

    return CustomerStats(
        customers_last_30_days=len(recent_customers),
        new_last_30_days=len(new),
        returning_last_30_days=len(recent_customers) - len(new),
        return_rate=came_back / len(cohort) if cohort else None,
        at_risk=at_risk[:10],
    )


# ------------------------------------------------------------ suggestions


@dataclasses.dataclass(frozen=True)
class Suggestion:
    kind: str
    title: str
    detail: str
    monthly_gain_cents: int
    assumptions: str


def _money(cents: float, symbol: str) -> str:
    return f"{symbol}{round(cents / 100):,}"


def suggestions(
    data: ShopData,
    now: datetime.datetime,
    cells: list[HeatCell],
    customers: CustomerStats,
    services: list[ServiceStats],
    currency_symbol: str,
) -> list[Suggestion]:
    """Concrete moves with their expected monthly effect, best first. Every
    estimate states its assumptions — they're honest guesses, not promises."""
    recent = [b for b in _completed(data) if now - datetime.timedelta(days=SERVICE_WINDOW_DAYS) <= b.start < now]
    if len(recent) < MIN_BOOKINGS_FOR_SUGGESTIONS:
        return []
    ticket = sum(b.price_cents for b in recent) / len(recent)
    duration = statistics.mean((b.end - b.start).total_seconds() / 60 for b in recent)
    to_month = _DAYS_PER_MONTH / UTILISATION_WINDOW_DAYS
    found: list[Suggestion] = []

    # 1. The quietest 2-hour stretch: an off-peak "2 cuts for the price of 1.5".
    by_key = {(c.weekday, c.hour): c for c in cells}
    windows = []
    for (weekday, hour), cell in by_key.items():
        following = by_key.get((weekday, hour + 1))
        if following is None:
            continue
        available = cell.available_minutes + following.available_minutes
        booked = cell.booked_minutes + following.booked_minutes
        windows.append((booked / available, weekday, hour, available, booked))
    if windows:
        util, weekday, hour, available, booked = min(windows)
        current = booked * to_month / duration
        spare = (available - booked) * to_month / duration
        discount_cost = 0.25 * ticket * current
        needed = max(1, math.ceil(discount_cost / (0.75 * ticket)))
        fill = 0.25 * spare
        gain = 0.75 * ticket * fill - discount_cost
        if util < 0.4 and needed <= spare and gain > 0:
            found.append(
                Suggestion(
                    kind="quiet_window",
                    title=f"Fill quiet {_WEEKDAYS[weekday]}s, {hour:02d}:00–{hour + 2:02d}:00",
                    detail=(
                        f"Only {round(util * 100)}% booked. Offer 25% off in that window — '2 cuts for the "
                        f"price of 1.5'. It pays for itself with {needed} extra booking{'s' if needed != 1 else ''} "
                        f"a month, and there's room for about {round(spare)}."
                    ),
                    monthly_gain_cents=round(gain),
                    assumptions="Assumes the offer fills a quarter of the empty slots in that window; "
                    "existing bookings there also get the discount.",
                )
            )

    # 2. Second visit in the month for one-visit customers.
    since = now - datetime.timedelta(days=RECENT_WINDOW_DAYS)
    visits: dict[str, int] = {}
    for b in _completed(data):
        if since <= b.start < now:
            visits[b.customer_id] = visits.get(b.customer_id, 0) + 1
    once = sum(1 for v in visits.values() if v == 1)
    repeat = len(visits) - once
    gain = 0.5 * ticket * (0.2 * once - repeat)
    if once >= 5 and gain > 0:
        found.append(
            Suggestion(
                kind="second_visit_bundle",
                title="Sell '2 cuts for the price of 1.5' this month",
                detail=(
                    f"{once} of your {len(visits)} customers came once in the last 30 days. A two-cut bundle "
                    f"used within the month turns a single {_money(ticket, currency_symbol)} visit into "
                    f"{_money(1.5 * ticket, currency_symbol)}."
                ),
                monthly_gain_cents=round(gain),
                assumptions="Assumes 1 in 5 one-visit customers buys it, and every customer who already "
                "comes twice switches to the cheaper bundle.",
            )
        )

    # 3. Price rise on the service carrying the shop, when chairs are full.
    utilisation = overall_utilisation(cells) or 0.0
    if services:
        top = services[0]
        if top.bookings >= MIN_BOOKINGS_FOR_SUGGESTIONS and (utilisation >= 0.75 or top.share >= 0.4):
            monthly_revenue = top.revenue_cents * _DAYS_PER_MONTH / SERVICE_WINDOW_DAYS
            gain = monthly_revenue * (1.10 * 0.95 - 1)
            reason = (
                f"your chairs are {round(utilisation * 100)}% booked"
                if utilisation >= 0.75
                else f"it's {round(top.share * 100)}% of your bookings"
            )
            found.append(
                Suggestion(
                    kind="price_rise",
                    title=f"Raise {top.name} by 10%",
                    detail=f"Demand is strong — {reason}. A 10% rise on your main service still comes out ahead "
                    "even if a few customers go elsewhere.",
                    monthly_gain_cents=round(gain),
                    assumptions="Assumes 5% fewer bookings of that service after the rise.",
                )
            )

    # 4. Win back overdue regulars.
    if customers.at_risk:
        count = len(customers.at_risk)
        gain = count * 0.3 * 0.85 * ticket
        found.append(
            Suggestion(
                kind="win_back",
                title=f"Win back {count} regular{'s' if count != 1 else ''}",
                detail=f"{count} customer{'s' if count != 1 else ''} who used to come regularly "
                f"{'are' if count != 1 else 'is'} well overdue. Message them with 15% off their next cut.",
                monthly_gain_cents=round(gain),
                assumptions="Assumes 3 in 10 come back for one visit.",
            )
        )

    return sorted(found, key=lambda s: s.monthly_gain_cents, reverse=True)
