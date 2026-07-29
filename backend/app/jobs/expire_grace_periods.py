import logging

import stripe
from sqlalchemy import text
from sqlalchemy.orm import Session

import app.core.stripe_client  # noqa: F401 — sets stripe.api_key on import

logger = logging.getLogger(__name__)

GRACE_PERIOD_DAYS = 60


def find_and_delete_expired_businesses(db: Session) -> list[str]:
    """Businesses suspended (unpaid) for longer than the grace period get
    hard-deleted — every FK to `businesses` is `on delete cascade`, so this
    takes services, workers, bookings, reviews, etc. with it. Grandfathered
    (pre-billing) rows are never marked 'suspended' in the first place, so
    they're excluded by the status filter without any special-casing here.
    """
    rows = db.execute(
        text(
            # 'canceled' is included alongside 'suspended': once Stripe gives
            # up retrying it fires customer.subscription.deleted, which
            # flips status to 'canceled' — but the grace clock is
            # suspended_at, not the status string, so a canceled-but-still
            # -within-grace-period subscription must still be caught here.
            "select business_id, stripe_subscription_id from business_subscriptions "
            "where status in ('suspended', 'canceled') and grandfathered = false "
            "and suspended_at is not null and suspended_at < now() - make_interval(days => :days)"
        ),
        {"days": GRACE_PERIOD_DAYS},
    ).mappings().all()

    deleted_ids: list[str] = []
    for row in rows:
        if row["stripe_subscription_id"]:
            try:
                stripe.Subscription.cancel(row["stripe_subscription_id"])
            except stripe.error.StripeError:
                logger.warning(
                    "Could not cancel Stripe subscription %s during grace-period deletion",
                    row["stripe_subscription_id"],
                    exc_info=True,
                )
        db.execute(text("delete from businesses where id = :business_id"), {"business_id": row["business_id"]})
        deleted_ids.append(str(row["business_id"]))

    db.commit()
    return deleted_ids
