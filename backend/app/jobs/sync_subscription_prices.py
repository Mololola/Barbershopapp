import logging

import stripe
from sqlalchemy import text
from sqlalchemy.orm import Session

import app.core.stripe_client  # noqa: F401 — sets stripe.api_key on import
from app.api.billing import _PRICE_MULTIPLIER

logger = logging.getLogger(__name__)


def sync_subscription_prices(db: Session) -> list[str]:
    """Moves every running subscription whose shop's basic cut price changed
    to the new price, from its next payment (no proration). Services are
    written straight to Supabase, so this — not the app — is what keeps the
    price honest. A shop with no basic cut keeps its current price."""
    rows = db.execute(
        text(
            "select s.business_id, s.stripe_subscription_id, sv.price_cents * :multiplier as amount "
            "from business_subscriptions s "
            "join services sv on sv.business_id = s.business_id and sv.is_active and sv.is_basic_cut "
            "where s.stripe_subscription_id is not null and s.status in ('active', 'suspended') "
            "and not s.grandfathered and sv.price_cents * :multiplier <> s.monthly_amount_cents"
        ),
        {"multiplier": _PRICE_MULTIPLIER},
    ).mappings().all()

    synced: list[str] = []
    for row in rows:
        try:
            subscription = stripe.Subscription.retrieve(row["stripe_subscription_id"]).to_dict()
            item = subscription["items"]["data"][0]
            stripe.Subscription.modify(
                subscription["id"],
                items=[
                    {
                        "id": item["id"],
                        "price_data": {
                            "currency": item["price"]["currency"],
                            "product": item["price"]["product"],
                            "unit_amount": row["amount"],
                            "recurring": {"interval": "month"},
                        },
                    }
                ],
                proration_behavior="none",
            )
        except stripe.error.StripeError:
            # Left unsynced, so the next run retries it.
            logger.warning("Could not update the price of subscription %s", row["stripe_subscription_id"], exc_info=True)
            continue
        db.execute(
            text("update business_subscriptions set monthly_amount_cents = :amount where business_id = :business_id"),
            {"amount": row["amount"], "business_id": row["business_id"]},
        )
        synced.append(str(row["business_id"]))

    db.commit()
    return synced
