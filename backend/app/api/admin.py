import datetime
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api.billing import _DESIGN_SLOT_BUNDLE_PRICE_CENTS, _DESIGN_SLOT_BUNDLE_SIZE
from app.core.auth import get_current_user_id
from app.core.rate_limit import rate_limit
from app.db.session import get_db

router = APIRouter()

def require_admin(db: Session = Depends(get_db), user_id: str = Depends(get_current_user_id)) -> str:
    is_admin = db.execute(text("select is_admin from profiles where id = :id"), {"id": user_id}).scalar()
    if not is_admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Admins only")
    return user_id


class WindowedCount(BaseModel):
    """A running total plus how many were added recently — last 7 / 30
    days, and the 30 days before that so growth can be compared."""

    total: int
    last_7_days: int
    last_30_days: int
    previous_30_days: int


class CurrencyAmount(BaseModel):
    currency: str
    amount_cents: int
    count: int


class NamedCount(BaseModel):
    name: str
    count: int


class Reviewer(BaseModel):
    """A customer as a candidate for (or holder of) the quality-reviewer
    reward tier, with what the owner judges them on."""

    id: str
    username: str
    reviews: int
    # Mean characters written across a review's three optional comments.
    average_comment_length: int
    last_review_at: datetime.datetime | None
    member_since: datetime.datetime


class Reviewers(BaseModel):
    suggested: list[Reviewer]
    promoted: list[Reviewer]


class MonthTrend(BaseModel):
    month: str
    new_customers: int
    new_businesses: int
    completed_bookings: int


class UserMetrics(BaseModel):
    customers: WindowedCount
    business_accounts: WindowedCount
    minors: int
    workers_opted_in: int
    workers_looking_for_work: int
    sign_in_methods: list[NamedCount]
    awaiting_email_confirmation: int
    confirmed_without_profile: int


class BusinessMetrics(BaseModel):
    businesses: WindowedCount
    setup_complete: int
    bookable: int
    suspended: int
    subscriptions_by_status: list[NamedCount]
    grandfathered: int
    trials_active: int
    trials_ending_in_7_days: int
    trials_ended: int
    trials_converted_to_paying: int


class RevenueMetrics(BaseModel):
    monthly_recurring: list[CurrencyAmount]
    monthly_recurring_in_trial: list[CurrencyAmount]
    monthly_recurring_at_risk: list[CurrencyAmount]
    finance_tool_paid: list[CurrencyAmount]
    finance_tool_trials_active: int
    design_slot_bundles_sold: int
    design_slot_revenue_gbp_cents: int


class RewardMetrics(BaseModel):
    earned_cents: int
    earned_last_30_days_cents: int
    paid_out_cents: int
    pending_payouts: int
    pending_payouts_cents: int
    owed_cents: int
    quality_reviewers: int


class ActivityMetrics(BaseModel):
    bookings: WindowedCount
    upcoming_bookings: int
    completed_bookings: int
    cancelled_bookings: int
    reviews: WindowedCount
    average_shop_rating: float | None
    average_worker_rating: float | None
    average_haircut_rating: float | None
    monthly_trend: list[MonthTrend]


class AdminMetrics(BaseModel):
    users: UserMetrics
    businesses: BusinessMetrics
    revenue: RevenueMetrics
    rewards: RewardMetrics
    activity: ActivityMetrics


def _windowed(db: Session, source: str, created_column: str) -> WindowedCount:
    # `source` / `created_column` are only ever the literals passed below,
    # never user input.
    row = db.execute(
        text(
            f"select count(*) as total, "
            f"count(*) filter (where {created_column} >= now() - interval '7 days') as last_7_days, "
            f"count(*) filter (where {created_column} >= now() - interval '30 days') as last_30_days, "
            f"count(*) filter (where {created_column} >= now() - interval '60 days' "
            f"and {created_column} < now() - interval '30 days') as previous_30_days "
            f"from {source}"
        )
    ).mappings().one()
    return WindowedCount(**row)


def _scalar(db: Session, sql: str) -> int:
    return db.execute(text(sql)).scalar() or 0


def _named_counts(db: Session, sql: str) -> list[NamedCount]:
    return [NamedCount(name=row[0], count=row[1]) for row in db.execute(text(sql))]


def _per_currency(db: Session, where: str) -> list[CurrencyAmount]:
    rows = db.execute(
        text(
            "select b.currency, coalesce(sum(s.monthly_amount_cents), 0), count(*) "
            "from business_subscriptions s join businesses b on b.id = s.business_id "
            f"where {where} group by b.currency order by b.currency"
        )
    )
    return [CurrencyAmount(currency=r[0], amount_cents=r[1], count=r[2]) for r in rows]


# An admin-granted trial runs inside a Stripe subscription whose status is
# already 'active' from checkout — so "paying" means active, not
# grandfathered (free), and past any trial.
_IN_TRIAL = "b.subscription_trial_ends_at > now()"


def _user_metrics(db: Session) -> UserMetrics:
    return UserMetrics(
        customers=_windowed(db, "profiles where role = 'customer'", "created_at"),
        business_accounts=_windowed(db, "profiles where role = 'business'", "created_at"),
        minors=_scalar(
            db, "select count(*) from profiles where date_of_birth > (current_date - interval '18 years')::date"
        ),
        workers_opted_in=_scalar(db, "select count(*) from worker_profiles"),
        workers_looking_for_work=_scalar(db, "select count(*) from worker_profiles where is_looking_for_work"),
        sign_in_methods=_named_counts(
            db, "select provider, count(distinct user_id) from auth.identities group by provider order by 2 desc"
        ),
        awaiting_email_confirmation=_scalar(db, "select count(*) from auth.users where email_confirmed_at is null"),
        confirmed_without_profile=_scalar(
            db,
            "select count(*) from auth.users u where u.email_confirmed_at is not null "
            "and not exists (select 1 from profiles p where p.id = u.id)",
        ),
    )


def _business_metrics(db: Session) -> BusinessMetrics:
    return BusinessMetrics(
        businesses=_windowed(db, "businesses", "created_at"),
        setup_complete=_scalar(db, "select count(*) from businesses where setup_completed_at is not null"),
        bookable=_scalar(db, "select count(*) from businesses_public where is_bookable"),
        suspended=_scalar(db, "select count(*) from businesses where is_suspended"),
        subscriptions_by_status=_named_counts(
            db,
            "select coalesce(s.status, 'never subscribed'), count(*) from businesses b "
            "left join business_subscriptions s on s.business_id = b.id group by 1 order by 2 desc",
        ),
        grandfathered=_scalar(db, "select count(*) from business_subscriptions where grandfathered"),
        trials_active=_scalar(db, "select count(*) from businesses b where " + _IN_TRIAL),
        trials_ending_in_7_days=_scalar(
            db,
            "select count(*) from businesses where subscription_trial_ends_at > now() "
            "and subscription_trial_ends_at <= now() + interval '7 days'",
        ),
        trials_ended=_scalar(db, "select count(*) from businesses where subscription_trial_ends_at <= now()"),
        trials_converted_to_paying=_scalar(
            db,
            "select count(*) from businesses b join business_subscriptions s on s.business_id = b.id "
            "where b.subscription_trial_ends_at <= now() and s.status = 'active' and not s.grandfathered",
        ),
    )


def _revenue_metrics(db: Session) -> RevenueMetrics:
    finance_paid = db.execute(
        text(
            "select b.currency, coalesce(sum(f.amount_cents), 0), count(*) "
            "from business_finance_access f join businesses b on b.id = f.business_id "
            "where f.paid_at is not null group by b.currency order by b.currency"
        )
    )
    extra_slots = _scalar(db, "select coalesce(sum(extra_slots), 0) from design_extra_slots")
    bundles = extra_slots // _DESIGN_SLOT_BUNDLE_SIZE
    return RevenueMetrics(
        monthly_recurring=_per_currency(
            db, f"s.status = 'active' and not s.grandfathered and not coalesce({_IN_TRIAL}, false)"
        ),
        monthly_recurring_in_trial=_per_currency(db, f"s.status = 'active' and not s.grandfathered and {_IN_TRIAL}"),
        # Payment failed and in the grace period before auto-deletion.
        monthly_recurring_at_risk=_per_currency(db, "s.status = 'suspended'"),
        finance_tool_paid=[CurrencyAmount(currency=r[0], amount_cents=r[1], count=r[2]) for r in finance_paid],
        finance_tool_trials_active=_scalar(
            db,
            "select count(*) from business_finance_access "
            "where trial_ends_at > now() and paid_at is null and not grandfathered",
        ),
        design_slot_bundles_sold=bundles,
        design_slot_revenue_gbp_cents=bundles * _DESIGN_SLOT_BUNDLE_PRICE_CENTS,
    )


def _reward_metrics(db: Session) -> RewardMetrics:
    earned = _scalar(db, "select coalesce(sum(amount_cents), 0) from reward_ledger")
    paid = _scalar(db, "select coalesce(sum(amount_cents), 0) from payout_requests where status = 'paid'")
    return RewardMetrics(
        earned_cents=earned,
        earned_last_30_days_cents=_scalar(
            db, "select coalesce(sum(amount_cents), 0) from reward_ledger where created_at >= now() - interval '30 days'"
        ),
        paid_out_cents=paid,
        pending_payouts=_scalar(db, "select count(*) from payout_requests where status = 'pending'"),
        pending_payouts_cents=_scalar(
            db, "select coalesce(sum(amount_cents), 0) from payout_requests where status = 'pending'"
        ),
        owed_cents=earned - paid,
        quality_reviewers=_scalar(db, "select count(*) from profiles where is_quality_reviewer"),
    )


def _activity_metrics(db: Session) -> ActivityMetrics:
    ratings = db.execute(
        text(
            "select round(avg(shop_rating), 2), round(avg(worker_rating), 2), round(avg(haircut_rating), 2) "
            "from reviews"
        )
    ).one()
    trend = db.execute(
        text(
            "select to_char(m, 'YYYY-MM') as month, "
            "(select count(*) from profiles where role = 'customer' "
            " and date_trunc('month', created_at) = m) as new_customers, "
            "(select count(*) from businesses where date_trunc('month', created_at) = m) as new_businesses, "
            "(select count(*) from bookings where status = 'completed' "
            " and date_trunc('month', completed_at) = m) as completed_bookings "
            "from generate_series(date_trunc('month', now()) - interval '5 months', "
            "date_trunc('month', now()), interval '1 month') as m order by m"
        )
    )
    return ActivityMetrics(
        bookings=_windowed(db, "bookings", "created_at"),
        upcoming_bookings=_scalar(
            db, "select count(*) from bookings where status = 'confirmed' and start_time > now()"
        ),
        completed_bookings=_scalar(db, "select count(*) from bookings where status = 'completed'"),
        cancelled_bookings=_scalar(db, "select count(*) from bookings where status = 'cancelled'"),
        reviews=_windowed(db, "reviews", "created_at"),
        average_shop_rating=ratings[0],
        average_worker_rating=ratings[1],
        average_haircut_rating=ratings[2],
        monthly_trend=[MonthTrend(**row) for row in trend.mappings()],
    )


@router.get("/admin/metrics", response_model=AdminMetrics)
def admin_metrics(
    db: Session = Depends(get_db),
    _rate_limit: None = Depends(rate_limit("30/minute")),
    _admin: str = Depends(require_admin),
) -> AdminMetrics:
    """Everything the owner's Overview tab shows, computed here rather than
    in the app so the numbers are one consistent snapshot and no raw rows
    ever leave the server. Revenue is what the database knows from
    Stripe's webhooks — Stripe itself stays the source of truth for cash
    actually received, fees and refunds."""
    return AdminMetrics(
        users=_user_metrics(db),
        businesses=_business_metrics(db),
        revenue=_revenue_metrics(db),
        rewards=_reward_metrics(db),
        activity=_activity_metrics(db),
    )


# Only proven regulars are suggested: a single long review is easy to game,
# repeat reviews on real completed bookings aren't.
MIN_REVIEWS_FOR_SUGGESTION = 3

_REVIEWER_SELECT = """
    with stats as (
        select r.customer_id,
            count(*) as reviews,
            round(avg(
                length(btrim(coalesce(r.shop_comment, '')))
                + length(btrim(coalesce(r.worker_comment, '')))
                + length(btrim(coalesce(r.haircut_comment, '')))
            ))::int as average_comment_length,
            max(r.created_at) as last_review_at
        from reviews r
        join bookings b on b.id = r.booking_id and b.status = 'completed'
        group by r.customer_id
    )
    select p.id::text as id, p.username, coalesce(s.reviews, 0) as reviews,
        coalesce(s.average_comment_length, 0) as average_comment_length,
        s.last_review_at, p.created_at as member_since
    from profiles p left join stats s on s.customer_id = p.id
"""


@router.get("/admin/reviewers", response_model=Reviewers)
def admin_reviewers(
    db: Session = Depends(get_db),
    _rate_limit: None = Depends(rate_limit("30/minute")),
    _admin: str = Depends(require_admin),
) -> Reviewers:
    """Who to consider for the quality-reviewer tier, and who already has
    it (for demoting anyone the owner finds reviewing dishonestly).
    Suggestions rank by number of reviews, then by how much they write."""
    suggested = db.execute(
        text(
            _REVIEWER_SELECT
            + "where p.role = 'customer' and not p.is_quality_reviewer and s.reviews >= :min_reviews "
            "order by s.reviews desc, s.average_comment_length desc limit 20"
        ),
        {"min_reviews": MIN_REVIEWS_FOR_SUGGESTION},
    )
    promoted = db.execute(text(_REVIEWER_SELECT + "where p.is_quality_reviewer order by p.username"))
    return Reviewers(
        suggested=[Reviewer(**row) for row in suggested.mappings()],
        promoted=[Reviewer(**row) for row in promoted.mappings()],
    )


class QualityReviewerUpdate(BaseModel):
    is_quality_reviewer: bool


@router.post("/admin/customers/{customer_id}/quality-reviewer", status_code=status.HTTP_204_NO_CONTENT)
def set_quality_reviewer(
    customer_id: uuid.UUID,
    body: QualityReviewerUpdate,
    db: Session = Depends(get_db),
    _rate_limit: None = Depends(rate_limit("30/minute")),
    _admin: str = Depends(require_admin),
) -> None:
    """Promote a customer to (or demote from) the $3 reward tier. Done here,
    not as a client-side update: the app's database role deliberately has
    no UPDATE grant on is_quality_reviewer (see 'lock down profile
    privilege columns'), so nobody can promote themselves — which also
    means an admin's own client can't write it either."""
    updated = db.execute(
        text(
            "update profiles set is_quality_reviewer = :value "
            "where id = :customer_id and role = 'customer' returning id"
        ),
        {"value": body.is_quality_reviewer, "customer_id": customer_id},
    ).first()
    if updated is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Customer not found")
    db.commit()
