import logging

import stripe
from sqlalchemy import text
from sqlalchemy.orm import Session

import app.core.stripe_client  # noqa: F401 — sets stripe.api_key on import

logger = logging.getLogger(__name__)

# How long an unpaid business keeps its data (the owner can still sign in)
# after it stops being shown to customers.
GRACE_PERIOD_DAYS = 60


def find_and_delete_expired_businesses(db: Session) -> list[str]:
    """Businesses hidden from customers for unpaid billing (never subscribed,
    or lapsed — see business_hidden_since) for longer than the grace period
    get hard-deleted — every FK to `businesses` is `on delete cascade`, so
    this takes services, workers, bookings, reviews, etc. with it.
    """
    rows = db.execute(
        text(
            # Finance Premium is its own Stripe subscription — it would keep
            # billing after the business is gone if not canceled too.
            "select b.id as business_id, s.stripe_subscription_id, f.stripe_subscription_id as finance_subscription_id "
            "from businesses b "
            "left join business_subscriptions s on s.business_id = b.id "
            "left join business_finance_access f on f.business_id = b.id "
            "where business_hidden_since(b.id) < now() - make_interval(days => :days)"
        ),
        {"days": GRACE_PERIOD_DAYS},
    ).mappings().all()

    deleted_ids: list[str] = []
    for row in rows:
        for subscription_id in (row["stripe_subscription_id"], row["finance_subscription_id"]):
            if not subscription_id:
                continue
            try:
                stripe.Subscription.cancel(subscription_id)
            except stripe.error.StripeError:
                logger.warning(
                    "Could not cancel Stripe subscription %s during grace-period deletion",
                    subscription_id,
                    exc_info=True,
                )
        db.execute(text("delete from businesses where id = :business_id"), {"business_id": row["business_id"]})
        deleted_ids.append(str(row["business_id"]))

    db.commit()
    return deleted_ids
