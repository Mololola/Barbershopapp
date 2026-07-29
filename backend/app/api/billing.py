import uuid

import stripe
from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session

import app.core.stripe_client  # noqa: F401 — sets stripe.api_key on import
from app.core.auth import get_current_user_id
from app.core.config import settings
from app.db.session import get_db

router = APIRouter()

# The value of "10 haircuts" per the spec — a business's own average active
# service price, times this multiplier, becomes its monthly subscription.
_PRICE_MULTIPLIER = 10


class CheckoutSessionResponse(BaseModel):
    url: str


class PortalSessionResponse(BaseModel):
    url: str


def _is_business_owner(db: Session, business_id: uuid.UUID, user_id: str) -> bool:
    return (
        db.execute(
            text("select 1 from businesses where id = :business_id and owner_id = :user_id"),
            {"business_id": business_id, "user_id": user_id},
        ).first()
        is not None
    )


def _price_from_average(avg_price_cents: float | None) -> int | None:
    """The "value of 10 haircuts" pricing rule — pulled out of the DB-facing
    endpoint so it's testable without a database."""
    if avg_price_cents is None:
        return None
    return round(avg_price_cents * _PRICE_MULTIPLIER)


def _compute_monthly_amount_cents(db: Session, business_id: uuid.UUID) -> int:
    avg_price = db.execute(
        text("select avg(price_cents) from services where business_id = :business_id and is_active = true"),
        {"business_id": business_id},
    ).scalar()
    amount = _price_from_average(float(avg_price) if avg_price is not None else None)
    if amount is None:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Add at least one active service before subscribing — the subscription price is based on it.",
        )
    return amount


@router.post("/businesses/{business_id}/subscription/checkout", response_model=CheckoutSessionResponse)
def create_checkout_session(
    business_id: uuid.UUID,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
) -> CheckoutSessionResponse:
    if not _is_business_owner(db, business_id, user_id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your business")

    monthly_amount_cents = _compute_monthly_amount_cents(db, business_id)

    business = db.execute(
        text("select owner_id, currency, name from businesses where id = :business_id"),
        {"business_id": business_id},
    ).mappings().first()
    if business is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Business not found")

    existing = db.execute(
        text("select stripe_customer_id from business_subscriptions where business_id = :business_id"),
        {"business_id": business_id},
    ).mappings().first()

    if existing and existing["stripe_customer_id"]:
        customer_id = existing["stripe_customer_id"]
        db.execute(
            text("update business_subscriptions set monthly_amount_cents = :amount where business_id = :business_id"),
            {"amount": monthly_amount_cents, "business_id": business_id},
        )
    else:
        email = db.execute(
            text("select email from auth.users where id = :owner_id"),
            {"owner_id": business["owner_id"]},
        ).scalar()
        customer = stripe.Customer.create(email=email, metadata={"business_id": str(business_id)})
        customer_id = customer.id
        if existing:
            db.execute(
                text(
                    "update business_subscriptions set stripe_customer_id = :customer_id, "
                    "monthly_amount_cents = :amount where business_id = :business_id"
                ),
                {"customer_id": customer_id, "amount": monthly_amount_cents, "business_id": business_id},
            )
        else:
            db.execute(
                text(
                    "insert into business_subscriptions (business_id, stripe_customer_id, monthly_amount_cents, status) "
                    "values (:business_id, :customer_id, :amount, 'incomplete')"
                ),
                {"business_id": business_id, "customer_id": customer_id, "amount": monthly_amount_cents},
            )
    db.commit()

    # Known v1 gap: no deep link back into the app yet, so success/cancel
    # just land on a generic page — the webhook (not this redirect) is what
    # actually updates subscription state, so this doesn't block correctness.
    placeholder_return_url = f"{settings.supabase_url}/"

    session = stripe.checkout.Session.create(
        customer=customer_id,
        mode="subscription",
        line_items=[
            {
                "price_data": {
                    "currency": business["currency"].lower(),
                    "product_data": {"name": f"{business['name']} — monthly subscription"},
                    "unit_amount": monthly_amount_cents,
                    "recurring": {"interval": "month"},
                },
                "quantity": 1,
            }
        ],
        metadata={"business_id": str(business_id)},
        subscription_data={"metadata": {"business_id": str(business_id)}},
        success_url=f"{placeholder_return_url}?billing=success",
        cancel_url=f"{placeholder_return_url}?billing=cancelled",
    )
    return CheckoutSessionResponse(url=session.url)


@router.post("/businesses/{business_id}/subscription/portal", response_model=PortalSessionResponse)
def create_portal_session(
    business_id: uuid.UUID,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
) -> PortalSessionResponse:
    if not _is_business_owner(db, business_id, user_id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your business")

    customer_id = db.execute(
        text("select stripe_customer_id from business_subscriptions where business_id = :business_id"),
        {"business_id": business_id},
    ).scalar()
    if not customer_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "No billing account yet — subscribe first")

    portal_session = stripe.billing_portal.Session.create(
        customer=customer_id,
        return_url=f"{settings.supabase_url}/",
    )
    return PortalSessionResponse(url=portal_session.url)


def _handle_checkout_completed(db: Session, session: dict) -> None:
    if session.get("mode") != "subscription":
        return
    business_id = session["metadata"]["business_id"]
    db.execute(
        text(
            "update business_subscriptions set stripe_subscription_id = :sub, status = 'active' "
            "where business_id = :business_id"
        ),
        {"sub": session["subscription"], "business_id": business_id},
    )
    db.execute(text("update businesses set is_suspended = false where id = :business_id"), {"business_id": business_id})


def _handle_invoice_payment_failed(db: Session, invoice: dict) -> None:
    subscription_id = invoice.get("subscription")
    if not subscription_id:
        return
    # coalesce: the 2-month grace clock starts on the *first* failure, not
    # reset by every Stripe retry against the same still-unpaid invoice.
    db.execute(
        text(
            "update business_subscriptions set status = 'suspended', suspended_at = coalesce(suspended_at, now()) "
            "where stripe_subscription_id = :sub"
        ),
        {"sub": subscription_id},
    )
    business_id = db.execute(
        text("select business_id from business_subscriptions where stripe_subscription_id = :sub"),
        {"sub": subscription_id},
    ).scalar()
    if business_id:
        db.execute(text("update businesses set is_suspended = true where id = :business_id"), {"business_id": business_id})


def _handle_invoice_payment_succeeded(db: Session, invoice: dict) -> None:
    subscription_id = invoice.get("subscription")
    if not subscription_id:
        return
    db.execute(
        text(
            "update business_subscriptions set status = 'active', suspended_at = null "
            "where stripe_subscription_id = :sub"
        ),
        {"sub": subscription_id},
    )
    business_id = db.execute(
        text("select business_id from business_subscriptions where stripe_subscription_id = :sub"),
        {"sub": subscription_id},
    ).scalar()
    if business_id:
        db.execute(text("update businesses set is_suspended = false where id = :business_id"), {"business_id": business_id})


def _handle_subscription_deleted(db: Session, subscription: dict) -> None:
    # Stripe gave up retrying and canceled the subscription itself. Our own
    # 60-day clock from suspended_at (not this event) still drives the hard
    # delete — see app/jobs/expire_grace_periods.py.
    db.execute(
        text("update business_subscriptions set status = 'canceled' where stripe_subscription_id = :sub"),
        {"sub": subscription["id"]},
    )


_WEBHOOK_HANDLERS = {
    "checkout.session.completed": _handle_checkout_completed,
    "invoice.payment_failed": _handle_invoice_payment_failed,
    "invoice.payment_succeeded": _handle_invoice_payment_succeeded,
    "customer.subscription.deleted": _handle_subscription_deleted,
}


@router.post("/webhooks/stripe")
async def stripe_webhook(request: Request, db: Session = Depends(get_db)) -> dict:
    payload = await request.body()
    signature = request.headers.get("stripe-signature", "")
    try:
        event = stripe.Webhook.construct_event(payload, signature, settings.stripe_webhook_secret)
    except (ValueError, stripe.error.SignatureVerificationError) as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid signature") from exc

    already_processed = db.execute(
        text("select 1 from stripe_events where id = :id"), {"id": event["id"]}
    ).first()
    if already_processed:
        return {"received": True, "skipped": True}

    handler = _WEBHOOK_HANDLERS.get(event["type"])
    if handler:
        handler(db, event["data"]["object"])

    db.execute(
        text("insert into stripe_events (id, type) values (:id, :type)"),
        {"id": event["id"], "type": event["type"]},
    )
    db.commit()
    return {"received": True}
