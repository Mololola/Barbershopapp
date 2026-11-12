import datetime
import uuid
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.auth import get_current_user_id
from app.core.config import settings
from app.core.i18n import is_spanish
from app.core.rate_limit import rate_limit
from app.db.session import get_db
from app.services import finance_analytics as fa

router = APIRouter()

_CURRENCY_SYMBOLS = {"GBP": "£", "EUR": "€", "USD": "$"}


# ----------------------------------------------------------------- access


class PremiumState(BaseModel):
    has_premium: bool
    trial_ends_at: datetime.datetime | None
    trial_used: bool
    subscribed: bool


def finance_premium_state(db: Session, business_id: uuid.UUID) -> PremiumState:
    """Premium is on for: a running free trial, an active (or retrying)
    monthly subscription, a legacy one-off unlock, or a grandfathered shop —
    and for everyone while it's free (`finance_premium_free`), reported as
    subscribed so no trial or checkout is offered."""
    if settings.finance_premium_free:
        return PremiumState(has_premium=True, trial_ends_at=None, trial_used=False, subscribed=True)
    row = db.execute(
        text(
            "select grandfathered, paid_at, trial_ends_at, subscription_status "
            "from business_finance_access where business_id = :business_id"
        ),
        {"business_id": business_id},
    ).mappings().first()
    if row is None:
        return PremiumState(has_premium=False, trial_ends_at=None, trial_used=False, subscribed=False)
    now = datetime.datetime.now(datetime.UTC)
    trial_running = row["trial_ends_at"] is not None and row["trial_ends_at"] > now
    subscribed = row["subscription_status"] in ("active", "past_due")
    return PremiumState(
        has_premium=bool(row["grandfathered"]) or row["paid_at"] is not None or trial_running or subscribed,
        trial_ends_at=row["trial_ends_at"] if trial_running else None,
        trial_used=row["trial_ends_at"] is not None,
        subscribed=subscribed or bool(row["grandfathered"]) or row["paid_at"] is not None,
    )


# -------------------------------------------------------------- responses


class MonthOut(BaseModel):
    month: datetime.date
    booking_revenue_cents: int
    other_income_cents: int
    revenue_cents: int
    costs_cents: int
    net_cents: int
    completed_bookings: int


class FreeSummary(MonthOut):
    average_ticket_cents: int
    bookings_to_break_even: int | None


class ForecastOut(BaseModel):
    projected_revenue_cents: int
    projected_net_cents: int
    confirmed_upcoming_cents: int
    break_even_day: datetime.date | None
    already_broken_even: bool


class HeatCellOut(BaseModel):
    weekday: int
    hour: int
    utilisation: float | None


class BarberOut(BaseModel):
    name: str
    bookings: int
    revenue_cents: int
    utilisation: float | None
    average_rating: float | None


class ServiceOut(BaseModel):
    name: str
    bookings: int
    revenue_cents: int
    share: float
    previous_bookings: int


class AtRiskOut(BaseModel):
    username: str
    visits: int
    last_visit: datetime.date
    usual_gap_days: int
    days_since: int


class CustomersOut(BaseModel):
    customers_last_30_days: int
    new_last_30_days: int
    returning_last_30_days: int
    return_rate: float | None
    at_risk: list[AtRiskOut]


class SuggestionOut(BaseModel):
    kind: str
    title: str
    detail: str
    monthly_gain_cents: int
    assumptions: str


class Premium(BaseModel):
    forecast: ForecastOut | None  # only for the current month
    history: list[MonthOut]  # 12 months, oldest first, ending at the requested month
    utilisation: float | None
    heatmap: list[HeatCellOut]
    barbers: list[BarberOut]
    services: list[ServiceOut]
    customers: CustomersOut
    suggestions: list[SuggestionOut]
    average_ticket_cents: int
    average_duration_minutes: float | None


class FinanceOverview(BaseModel):
    currency: str
    month: datetime.date
    is_current_month: bool
    premium_state: PremiumState
    summary: FreeSummary
    premium: Premium | None


# ------------------------------------------------------------------ loading


def _load(db: Session, business_id: uuid.UUID, tz: datetime.tzinfo, since: datetime.datetime) -> fa.ShopData:
    params = {"business_id": business_id}
    bookings = [
        fa.BookingRow(
            start=r["start_time"],
            end=r["end_time"],
            status=r["status"],
            price_cents=r["price_cents"],
            worker_id=str(r["worker_id"]),
            service_id=str(r["service_id"]),
            customer_id=str(r["customer_id"]),
        )
        for r in db.execute(
            text(
                "select start_time, end_time, status, price_cents, worker_id, service_id, customer_id "
                "from bookings where business_id = :business_id and start_time >= :since"
            ),
            {**params, "since": since},
        ).mappings()
    ]
    costs = [
        fa.CostRow(kind=r["kind"], amount_cents=r["amount_cents"], starts_on=r["starts_on"], ends_on=r["ends_on"])
        for r in db.execute(
            text("select kind, amount_cents, starts_on, ends_on from business_cost_items where business_id = :business_id"),
            params,
        ).mappings()
    ]
    income = {
        r["month"]: r["amount_cents"]
        for r in db.execute(
            text("select month, amount_cents from business_other_income where business_id = :business_id"), params
        ).mappings()
    }
    hours_columns = "day_of_week, is_closed, open_time, close_time, break_start, break_end"
    business_hours = {
        r["day_of_week"]: dict(r)
        for r in db.execute(
            text(f"select {hours_columns} from opening_hours where business_id = :business_id"), params
        ).mappings()
    }
    workers = {
        str(r["id"]): r["name"]
        for r in db.execute(
            text("select id, name from workers where business_id = :business_id and is_active"), params
        ).mappings()
    }
    schedules: dict[str, dict[int, dict]] = {}
    for r in db.execute(
        text(
            f"select worker_id, {hours_columns} from worker_schedules "
            "where worker_id in (select id from workers where business_id = :business_id and is_active)"
        ),
        params,
    ).mappings():
        schedules.setdefault(str(r["worker_id"]), {})[r["day_of_week"]] = dict(r)
    services = db.execute(
        text("select id, name, price_cents, is_active from services where business_id = :business_id"), params
    ).mappings().all()
    active_prices = [s["price_cents"] for s in services if s["is_active"]]
    first_visit = {
        str(r["customer_id"]): r["first"]
        for r in db.execute(
            text(
                "select customer_id, min(start_time) as first from bookings "
                "where business_id = :business_id and status = 'completed' group by customer_id"
            ),
            params,
        ).mappings()
    }
    ratings = {
        str(r["worker_id"]): float(r["rating"])
        for r in db.execute(
            text(
                "select worker_id, round(avg(worker_rating), 1) as rating from reviews "
                "where business_id = :business_id and worker_rating is not null group by worker_id"
            ),
            params,
        ).mappings()
    }
    return fa.ShopData(
        tz=tz,
        bookings=bookings,
        costs=costs,
        other_income=income,
        business_hours=business_hours,
        worker_names=workers,
        worker_schedules=schedules,
        service_names={str(s["id"]): s["name"] for s in services},
        average_service_price_cents=round(sum(active_prices) / len(active_prices)) if active_prices else 0,
        first_visit=first_visit,
        worker_ratings=ratings,
    )


def _month_out(figures: fa.MonthFigures) -> MonthOut:
    return MonthOut(
        month=figures.month,
        booking_revenue_cents=figures.booking_revenue_cents,
        other_income_cents=figures.other_income_cents,
        revenue_cents=figures.revenue_cents,
        costs_cents=figures.costs_cents,
        net_cents=figures.net_cents,
        completed_bookings=figures.completed_bookings,
    )


# ----------------------------------------------------------------- endpoint


@router.get("/businesses/{business_id}/finance", response_model=FinanceOverview)
def finance_overview(
    business_id: uuid.UUID,
    month: str | None = Query(default=None, pattern=r"^\d{4}-(0[1-9]|1[0-2])$", description="YYYY-MM"),
    db: Session = Depends(get_db),
    _rate_limit: None = Depends(rate_limit("30/minute")),
    user_id: str = Depends(get_current_user_id),
    accept_language: str | None = Header(default=None),
) -> FinanceOverview:
    """The finance tool for one month: the free summary for every business,
    plus the premium analysis only when premium is on — enforced here, not
    just hidden in the app."""
    business = db.execute(
        text("select owner_id, currency, time_zone from businesses where id = :business_id"),
        {"business_id": business_id},
    ).mappings().first()
    if business is None or str(business["owner_id"]) != user_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your business")

    tz = ZoneInfo(business["time_zone"])
    now = datetime.datetime.now(datetime.UTC)
    current_month = fa.month_start(now.astimezone(tz).date())
    if month is None:
        selected = current_month
    else:
        year, number = (int(part) for part in month.split("-"))
        selected = datetime.date(year, number, 1)
        if selected > current_month:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "That month hasn't happened yet")

    premium_state = finance_premium_state(db, business_id)
    earliest = fa.add_months(min(selected, fa.add_months(current_month, -6)), -11)
    data = _load(db, business_id, tz, datetime.datetime.combine(earliest, datetime.time.min, tzinfo=tz))

    figures = fa.month_figures(data, selected)
    ticket = fa.average_ticket_cents(figures, data.average_service_price_cents)
    summary = FreeSummary(
        **_month_out(figures).model_dump(),
        average_ticket_cents=ticket,
        bookings_to_break_even=fa.bookings_to_break_even(figures, ticket),
    )

    premium = None
    if premium_state.has_premium:
        cells = fa.utilisation_heatmap(data, now)
        customers = fa.customer_stats(data, now)
        services = fa.service_stats(data, now)
        recent = [b for b in data.bookings if b.status == "completed" and b.start >= now - datetime.timedelta(days=90)]
        usernames = {
            str(r["id"]): r["username"]
            for r in db.execute(
                text("select id, username from profiles where id = any(:ids)"),
                {"ids": [uuid.UUID(c.customer_id) for c in customers.at_risk]},
            ).mappings()
        }
        forecast = fa.forecast_month(data, selected, now) if selected == current_month else None
        premium = Premium(
            forecast=ForecastOut(**forecast.__dict__) if forecast else None,
            history=[_month_out(fa.month_figures(data, fa.add_months(selected, -i))) for i in range(11, -1, -1)],
            utilisation=fa.overall_utilisation(cells),
            heatmap=[HeatCellOut(weekday=c.weekday, hour=c.hour, utilisation=c.utilisation) for c in cells],
            barbers=[
                BarberOut(
                    name=b.name,
                    bookings=b.bookings,
                    revenue_cents=b.revenue_cents,
                    utilisation=b.utilisation,
                    average_rating=b.average_rating,
                )
                for b in fa.barber_stats(data, now)
            ],
            services=[ServiceOut(**s.__dict__) for s in services],
            customers=CustomersOut(
                customers_last_30_days=customers.customers_last_30_days,
                new_last_30_days=customers.new_last_30_days,
                returning_last_30_days=customers.returning_last_30_days,
                return_rate=customers.return_rate,
                at_risk=[
                    AtRiskOut(
                        username=usernames.get(c.customer_id, "customer"),
                        visits=c.visits,
                        last_visit=c.last_visit,
                        usual_gap_days=c.usual_gap_days,
                        days_since=c.days_since,
                    )
                    for c in customers.at_risk
                ],
            ),
            suggestions=[
                SuggestionOut(**s.__dict__)
                for s in fa.suggestions(
                    data,
                    now,
                    cells,
                    customers,
                    services,
                    _CURRENCY_SYMBOLS.get(business["currency"], ""),
                    spanish=is_spanish(accept_language),
                )
            ],
            average_ticket_cents=round(sum(b.price_cents for b in recent) / len(recent)) if recent else ticket,
            average_duration_minutes=(
                sum((b.end - b.start).total_seconds() / 60 for b in recent) / len(recent) if recent else None
            ),
        )

    return FinanceOverview(
        currency=business["currency"],
        month=selected,
        is_current_month=selected == current_month,
        premium_state=premium_state,
        summary=summary,
        premium=premium,
    )
