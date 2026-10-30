import logging
import uuid

import stripe
from sqlalchemy import text
from sqlalchemy.orm import Session

import app.core.stripe_client  # noqa: F401 — sets stripe.api_key on import
from app.api.billing import _PRICE_MULTIPLIER, shop_monthly_cents

logger = logging.getLogger(__name__)


def set_monthly_amount(subscription_id: str, amount_cents: int) -> bool:
    """Moves a subscription to a new monthly price from its next payment (no
    proration). False if Stripe refused, so the caller retries later."""
    try:
        subscription = stripe.Subscription.retrieve(subscription_id).to_dict()
        item = subscription["items"]["data"][0]
        stripe.Subscription.modify(
            subscription["id"],
            items=[
                {
                    "id": item["id"],
                    "price_data": {
                        "currency": item["price"]["currency"],
                        "product": item["price"]["product"],
                        "unit_amount": amount_cents,
                        "recurring": {"interval": "month"},
                    },
                }
            ],
            proration_behavior="none",
        )
    except stripe.error.StripeError:
        logger.warning("Could not update the price of subscription %s", subscription_id, exc_info=True)
        return False
    return True


def sync_subscription_prices(db: Session, business_id: uuid.UUID | None = None) -> list[str]:
    """Moves every running subscription whose price changed — its shop's
    basic cut price, or the loyalty discount after more months paid — to
    the new price, from its next payment. Services are written straight to
    Supabase, so this — not the app — is what keeps the price honest. A shop
    with no basic cut keeps its current price. With [business_id], only
    that shop — so an owner's change applies at once."""
    rows = db.execute(
        text(
            "select s.business_id, s.stripe_subscription_id, s.monthly_amount_cents, "
            "sv.price_cents * :multiplier as full_price, "
            "(select count(*) from subscription_paid_invoices i "
            " where i.stripe_subscription_id = s.stripe_subscription_id) as paid_months "
            "from business_subscriptions s "
            "join services sv on sv.business_id = s.business_id and sv.is_active and sv.is_basic_cut "
            "where s.stripe_subscription_id is not null and s.status in ('active', 'suspended') "
            "and not s.grandfathered "
            "and (cast(:business_id as uuid) is null or s.business_id = :business_id)"
        ),
        {"multiplier": _PRICE_MULTIPLIER, "business_id": business_id},
    ).mappings().all()

    synced: list[str] = []
    for row in rows:
        amount = shop_monthly_cents(row["full_price"], row["paid_months"])
        # Left unsynced when Stripe refuses, so the next run retries it.
        if amount == row["monthly_amount_cents"] or not set_monthly_amount(row["stripe_subscription_id"], amount):
            continue
        db.execute(
            text("update business_subscriptions set monthly_amount_cents = :amount where business_id = :business_id"),
            {"amount": amount, "business_id": row["business_id"]},
        )
        synced.append(str(row["business_id"]))

    db.commit()
    return synced
