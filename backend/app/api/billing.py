import calendar
import uuid
from datetime import datetime, timezone

import stripe
from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session

import app.core.stripe_client  # noqa: F401 — sets stripe.api_key on import
from app.core.auth import get_current_user_id
from app.core.config import settings
from app.core.rate_limit import limiter, rate_limit
from app.db.session import get_db

router = APIRouter()

# The value of "10 haircuts" per the spec — a business's own average active
# service price, times this multiplier, becomes its monthly subscription.
_PRICE_MULTIPLIER = 10

# Finance tool: a flat one-off unlock, not tied to service pricing.
_FINANCE_ACCESS_PRICE_CENTS = 4500

# 3D designer: a repeatable, per-user bundle — buy again any time you fill
# up. Fixed GBP price since profiles (unlike businesses) have no currency.
_DESIGN_SLOT_BUNDLE_SIZE = 2
_DESIGN_SLOT_BUNDLE_PRICE_CENTS = 200


class CheckoutSessionResponse(BaseModel):
    url: str


class PortalSessionResponse(BaseModel):
    url: str


class OkResponse(BaseModel):
    ok: bool = True


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
    _rate_limit: None = Depends(rate_limit("5/minute")),  # each call is a real Stripe API round-trip
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
    _rate_limit: None = Depends(rate_limit("5/minute")),  # each call is a real Stripe API round-trip
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


def _add_one_calendar_month(dt: datetime) -> datetime:
    """Same day next month (Jan 1 -> Feb 1, Apr 15 -> May 15), clamped to the
    target month's last day when it doesn't have that day (Jan 31 -> Feb
    28/29) — the "1 month free trial" the user described by example."""
    year = dt.year + dt.month // 12
    month = dt.month % 12 + 1
    day = min(dt.day, calendar.monthrange(year, month)[1])
    return dt.replace(year=year, month=month, day=day)


def _finance_access_row(db: Session, business_id: uuid.UUID):
    return db.execute(
        text("select grandfathered, paid_at from business_finance_access where business_id = :business_id"),
        {"business_id": business_id},
    ).mappings().first()


@router.post("/businesses/{business_id}/finance-access/trial", response_model=OkResponse)
def start_finance_trial(
    business_id: uuid.UUID,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
) -> OkResponse:
    if not _is_business_owner(db, business_id, user_id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your business")

    if _finance_access_row(db, business_id) is not None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Finance tool access was already started for this business")

    now = datetime.now(timezone.utc)
    db.execute(
        text(
            "insert into business_finance_access (business_id, trial_started_at, trial_ends_at) "
            "values (:business_id, :started, :ends)"
        ),
        {"business_id": business_id, "started": now, "ends": _add_one_calendar_month(now)},
    )
    db.commit()
    return OkResponse()


@router.post("/businesses/{business_id}/finance-access/checkout", response_model=CheckoutSessionResponse)
def create_finance_access_checkout(
    business_id: uuid.UUID,
    db: Session = Depends(get_db),
    _rate_limit: None = Depends(rate_limit("5/minute")),  # each call is a real Stripe API round-trip
    user_id: str = Depends(get_current_user_id),
) -> CheckoutSessionResponse:
    if not _is_business_owner(db, business_id, user_id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your business")

    existing = _finance_access_row(db, business_id)
    if existing and (existing["grandfathered"] or existing["paid_at"] is not None):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Finance tool is already unlocked for this business")

    business = db.execute(
        text("select owner_id, currency, name from businesses where id = :business_id"),
        {"business_id": business_id},
    ).mappings().first()
    if business is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Business not found")

    email = db.execute(
        text("select email from auth.users where id = :owner_id"),
        {"owner_id": business["owner_id"]},
    ).scalar()

    placeholder_return_url = f"{settings.supabase_url}/"

    session = stripe.checkout.Session.create(
        customer_email=email,
        mode="payment",
        line_items=[
            {
                "price_data": {
                    "currency": business["currency"].lower(),
                    "product_data": {"name": f"{business['name']} — Finance tool (one-time unlock)"},
                    "unit_amount": _FINANCE_ACCESS_PRICE_CENTS,
                },
                "quantity": 1,
            }
        ],
        metadata={"business_id": str(business_id)},
        success_url=f"{placeholder_return_url}?billing=success",
        cancel_url=f"{placeholder_return_url}?billing=cancelled",
    )
    return CheckoutSessionResponse(url=session.url)


@router.post("/designer/extra-slots/checkout", response_model=CheckoutSessionResponse)
def create_design_slot_checkout(
    db: Session = Depends(get_db),
    _rate_limit: None = Depends(rate_limit("5/minute")),  # each call is a real Stripe API round-trip
    user_id: str = Depends(get_current_user_id),
) -> CheckoutSessionResponse:
    is_minor = db.execute(text("select profile_is_minor(p) from profiles p where p.id = :user_id"), {"user_id": user_id}).scalar()
    if is_minor:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Minor accounts can't make purchases.")

    email = db.execute(text("select email from auth.users where id = :user_id"), {"user_id": user_id}).scalar()

    placeholder_return_url = f"{settings.supabase_url}/"

    session = stripe.checkout.Session.create(
        customer_email=email,
        mode="payment",
        line_items=[
            {
                "price_data": {
                    "currency": "gbp",
                    "product_data": {"name": f"+{_DESIGN_SLOT_BUNDLE_SIZE} extra 3D design slots"},
                    "unit_amount": _DESIGN_SLOT_BUNDLE_PRICE_CENTS,
                },
                "quantity": 1,
            }
        ],
        metadata={"profile_id": str(user_id)},
        success_url=f"{placeholder_return_url}?billing=success",
        cancel_url=f"{placeholder_return_url}?billing=cancelled",
    )
    return CheckoutSessionResponse(url=session.url)


def _handle_checkout_completed(db: Session, session: dict) -> None:
    mode = session.get("mode")
    metadata = session.get("metadata", {})

    if mode == "subscription":
        business_id = metadata["business_id"]
        db.execute(
            text(
                "update business_subscriptions set stripe_subscription_id = :sub, status = 'active' "
                "where business_id = :business_id"
            ),
            {"sub": session["subscription"], "business_id": business_id},
        )
        db.execute(
            text("update businesses set is_suspended = false where id = :business_id"), {"business_id": business_id}
        )
    elif mode == "payment" and "business_id" in metadata:
        # Upsert: a business may pay without ever having started a trial, so
        # there might be no existing business_finance_access row yet.
        db.execute(
            text(
                "insert into business_finance_access (business_id, paid_at) values (:business_id, now()) "
                "on conflict (business_id) do update set paid_at = now()"
            ),
            {"business_id": metadata["business_id"]},
        )
    elif mode == "payment" and "profile_id" in metadata:
        # Upsert: a user may buy a bundle before ever hitting the free cap,
        # so there might be no existing design_extra_slots row yet.
        db.execute(
            text(
                "insert into design_extra_slots (profile_id, extra_slots) values (:profile_id, :n) "
                "on conflict (profile_id) do update set extra_slots = design_extra_slots.extra_slots + :n"
            ),
            {"profile_id": metadata["profile_id"], "n": _DESIGN_SLOT_BUNDLE_SIZE},
        )


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
@limiter.exempt  # already gated by signature verification below, not by our own rate limit —
# an attacker without the webhook secret is rejected for free, and a legitimate burst of
# Stripe events (many businesses' subscriptions renewing around the same time, etc.) must
# never be dropped just because it looks like a flood.
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
