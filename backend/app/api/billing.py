import uuid
from datetime import datetime, timedelta, timezone

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
from app.api.finance import finance_premium_state

router = APIRouter()

# The value of "10 haircuts" per the spec — a business's own average active
# service price, times this multiplier, becomes its monthly subscription.
_PRICE_MULTIPLIER = 10

# Finance tool premium: a flat monthly add-on (the basic finance summary
# is free for every business), in the shop's own currency.
_FINANCE_PREMIUM_MONTHLY_CENTS = 999
_FINANCE_TRIAL = timedelta(days=14)
# Tags the premium add-on's checkout/subscription so webhook handlers don't
# mistake it for the shop's main subscription.
_FINANCE_PRODUCT = "finance_premium"

# Per the spec, a referrer earns 5% of what the shop they signed up pays.
_REFERRAL_SHARE = 0.05

# 3D designer: a repeatable, per-user bundle — buy again any time you fill
# up. Fixed GBP price since profiles (unlike businesses) have no currency.
_DESIGN_SLOT_BUNDLE_SIZE = 2
_DESIGN_SLOT_BUNDLE_PRICE_CENTS = 200


def _return_url(outcome: str) -> str:
    """Where Stripe sends the browser after checkout or the billing portal —
    see app/api/billing_return.py."""
    return f"{settings.public_base_url}/billing/return?outcome={outcome}"


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


def _trial_end_timestamp(trial_ends_at: datetime | None, now: datetime) -> int | None:
    """An admin-granted trial that's already lapsed, or is too close to now,
    should just quietly stop applying rather than surface a Stripe error —
    Stripe itself requires trial_end at least 48h out. Returns a Unix
    timestamp (what Stripe's API wants) or None."""
    if trial_ends_at is None:
        return None
    if trial_ends_at < now + timedelta(hours=48):
        return None
    return int(trial_ends_at.timestamp())


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
        text("select owner_id, currency, name, subscription_trial_ends_at from businesses where id = :business_id"),
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

    subscription_data = {"metadata": {"business_id": str(business_id)}}
    trial_end = _trial_end_timestamp(business["subscription_trial_ends_at"], datetime.now(timezone.utc))
    if trial_end is not None:
        subscription_data["trial_end"] = trial_end

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
        subscription_data=subscription_data,
        success_url=_return_url("success"),
        cancel_url=_return_url("cancelled"),
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
        return_url=_return_url("portal"),
    )
    return PortalSessionResponse(url=portal_session.url)


_ACTIVE_SHOP_SUBSCRIPTION = (
    "select stripe_subscription_id from business_subscriptions where business_id = :business_id and status = 'active'"
)
_ACTIVE_FINANCE_SUBSCRIPTION = (
    "select stripe_subscription_id from business_finance_access "
    "where business_id = :business_id and subscription_status in ('active', 'past_due')"
)


def _set_cancel_at_period_end(
    db: Session, business_id: uuid.UUID, user_id: str, active_subscription_sql: str, cancel: bool
) -> OkResponse:
    if not _is_business_owner(db, business_id, user_id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your business")

    subscription_id = db.execute(text(active_subscription_sql), {"business_id": business_id}).scalar()
    if not subscription_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "No active subscription")

    # At period end, not now: during a trial the period ends with the trial,
    # so the owner keeps everything until then and is never charged.
    subscription = stripe.Subscription.modify(subscription_id, cancel_at_period_end=cancel).to_dict()
    # The webhook will record the same thing; doing it now means the app
    # shows the change as soon as this returns.
    _handle_subscription_updated(db, subscription)
    db.commit()
    return OkResponse()


@router.post("/businesses/{business_id}/subscription/cancel", response_model=OkResponse)
def cancel_subscription(
    business_id: uuid.UUID,
    db: Session = Depends(get_db),
    _rate_limit: None = Depends(rate_limit("5/minute")),  # each call is a real Stripe API round-trip
    user_id: str = Depends(get_current_user_id),
) -> OkResponse:
    return _set_cancel_at_period_end(db, business_id, user_id, _ACTIVE_SHOP_SUBSCRIPTION, cancel=True)


@router.post("/businesses/{business_id}/subscription/resume", response_model=OkResponse)
def resume_subscription(
    business_id: uuid.UUID,
    db: Session = Depends(get_db),
    _rate_limit: None = Depends(rate_limit("5/minute")),  # each call is a real Stripe API round-trip
    user_id: str = Depends(get_current_user_id),
) -> OkResponse:
    return _set_cancel_at_period_end(db, business_id, user_id, _ACTIVE_SHOP_SUBSCRIPTION, cancel=False)


@router.post("/businesses/{business_id}/finance-access/cancel", response_model=OkResponse)
def cancel_finance_premium(
    business_id: uuid.UUID,
    db: Session = Depends(get_db),
    _rate_limit: None = Depends(rate_limit("5/minute")),  # each call is a real Stripe API round-trip
    user_id: str = Depends(get_current_user_id),
) -> OkResponse:
    return _set_cancel_at_period_end(db, business_id, user_id, _ACTIVE_FINANCE_SUBSCRIPTION, cancel=True)


@router.post("/businesses/{business_id}/finance-access/resume", response_model=OkResponse)
def resume_finance_premium(
    business_id: uuid.UUID,
    db: Session = Depends(get_db),
    _rate_limit: None = Depends(rate_limit("5/minute")),  # each call is a real Stripe API round-trip
    user_id: str = Depends(get_current_user_id),
) -> OkResponse:
    return _set_cancel_at_period_end(db, business_id, user_id, _ACTIVE_FINANCE_SUBSCRIPTION, cancel=False)


@router.post("/businesses/{business_id}/finance-access/trial", response_model=OkResponse)
def start_finance_trial(
    business_id: uuid.UUID,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
) -> OkResponse:
    if not _is_business_owner(db, business_id, user_id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your business")

    state = finance_premium_state(db, business_id)
    if state.trial_used or state.has_premium:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This business has already had its free Premium trial")

    now = datetime.now(timezone.utc)
    # Upsert: a legacy/grandfathered row can't reach here (has_premium), but
    # a row can exist from an earlier, cancelled subscription.
    db.execute(
        text(
            "insert into business_finance_access (business_id, trial_started_at, trial_ends_at) "
            "values (:business_id, :started, :ends) "
            "on conflict (business_id) do update set trial_started_at = :started, trial_ends_at = :ends"
        ),
        {"business_id": business_id, "started": now, "ends": now + _FINANCE_TRIAL},
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

    if finance_premium_state(db, business_id).subscribed:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Finance Premium is already active for this business")

    business = db.execute(
        text("select owner_id, currency, name from businesses where id = :business_id"),
        {"business_id": business_id},
    ).mappings().first()
    if business is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Business not found")

    # The shop's existing Stripe customer when there is one, so Premium
    # shows up alongside the main subscription in the one billing portal.
    customer_id = db.execute(
        text("select stripe_customer_id from business_subscriptions where business_id = :business_id"),
        {"business_id": business_id},
    ).scalar()
    customer_args = (
        {"customer": customer_id}
        if customer_id
        else {
            "customer_email": db.execute(
                text("select email from auth.users where id = :owner_id"), {"owner_id": business["owner_id"]}
            ).scalar()
        }
    )

    metadata = {"business_id": str(business_id), "product": _FINANCE_PRODUCT}

    session = stripe.checkout.Session.create(
        **customer_args,
        mode="subscription",
        line_items=[
            {
                "price_data": {
                    "currency": business["currency"].lower(),
                    "product_data": {"name": f"{business['name']} — Finance Premium"},
                    "unit_amount": _FINANCE_PREMIUM_MONTHLY_CENTS,
                    "recurring": {"interval": "month"},
                },
                "quantity": 1,
            }
        ],
        metadata=metadata,
        subscription_data={"metadata": metadata},
        success_url=_return_url("success"),
        cancel_url=_return_url("cancelled"),
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
        success_url=_return_url("success"),
        cancel_url=_return_url("cancelled"),
    )
    return CheckoutSessionResponse(url=session.url)


def _handle_checkout_completed(db: Session, session: dict) -> None:
    mode = session.get("mode")
    metadata = session.get("metadata", {})

    if mode == "subscription" and metadata.get("product") == _FINANCE_PRODUCT:
        db.execute(
            text(
                "insert into business_finance_access (business_id, stripe_subscription_id, subscription_status) "
                "values (:business_id, :sub, 'active') "
                "on conflict (business_id) do update set stripe_subscription_id = :sub, subscription_status = 'active', "
                "cancel_at = null"
            ),
            {"business_id": metadata["business_id"], "sub": session["subscription"]},
        )
    elif mode == "subscription":
        db.execute(
            text(
                "update business_subscriptions set stripe_subscription_id = :sub, status = 'active', suspended_at = null "
                "where business_id = :business_id"
            ),
            {"sub": session["subscription"], "business_id": metadata["business_id"]},
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


def _invoice_subscription_id(invoice: dict) -> str | None:
    """Stripe API 2025-03-31 moved an invoice's subscription under
    `parent`; a webhook endpoint pinned to an older API version still sends
    the top-level field."""
    details = (invoice.get("parent") or {}).get("subscription_details") or {}
    return details.get("subscription") or invoice.get("subscription")


def _invoice_subscription_metadata(invoice: dict) -> dict:
    """The subscription's metadata as of this invoice — same API-version
    split as _invoice_subscription_id."""
    details = (invoice.get("parent") or {}).get("subscription_details") or invoice.get("subscription_details") or {}
    return details.get("metadata") or {}


def _from_unix(timestamp: int | None) -> datetime | None:
    return datetime.fromtimestamp(timestamp, timezone.utc) if timestamp else None


def _handle_invoice_payment_failed(db: Session, invoice: dict) -> None:
    subscription_id = _invoice_subscription_id(invoice)
    if not subscription_id:
        return
    # coalesce: the grace clock (business_hidden_since in f1c9a7d3e5b2)
    # starts on the *first* failure, not reset by every Stripe retry
    # against the same still-unpaid invoice.
    db.execute(
        text(
            "update business_subscriptions set status = 'suspended', suspended_at = coalesce(suspended_at, now()) "
            "where stripe_subscription_id = :sub"
        ),
        {"sub": subscription_id},
    )
    # Finance Premium stays usable while Stripe retries; it only lapses when
    # Stripe gives up and cancels (customer.subscription.deleted).
    db.execute(
        text("update business_finance_access set subscription_status = 'past_due' where stripe_subscription_id = :sub"),
        {"sub": subscription_id},
    )


def _handle_invoice_payment_succeeded(db: Session, invoice: dict) -> None:
    subscription_id = _invoice_subscription_id(invoice)
    if not subscription_id:
        return
    db.execute(
        text(
            "update business_subscriptions set status = 'active', suspended_at = null "
            "where stripe_subscription_id = :sub"
        ),
        {"sub": subscription_id},
    )
    db.execute(
        text("update business_finance_access set subscription_status = 'active' where stripe_subscription_id = :sub"),
        {"sub": subscription_id},
    )
    _credit_referral(db, invoice)
    _record_subscription_cost(db, invoice)


_THIS_MONTH = "date_trunc('month', now())::date"


def _record_subscription_cost(db: Session, invoice: dict) -> None:
    """What the shop pays us shows in its finance tool as a monthly cost,
    from the month it's first paid. A new amount counts from this month on,
    so earlier months keep what was paid then. Trial and proration invoices
    aren't the regular monthly price, so they're skipped."""
    metadata = _invoice_subscription_metadata(invoice)
    amount_cents = invoice.get("amount_paid", 0)
    if (
        invoice.get("billing_reason") not in ("subscription_create", "subscription_cycle")
        or amount_cents <= 0
        or "business_id" not in metadata
    ):
        return
    subscription_id = _invoice_subscription_id(invoice)
    current = db.execute(
        text(
            "select id, amount_cents, starts_on = " + _THIS_MONTH + " as started_this_month "
            "from business_cost_items where stripe_subscription_id = :sub and ends_on is null for update"
        ),
        {"sub": subscription_id},
    ).mappings().first()
    if current is not None:
        if current["amount_cents"] == amount_cents:
            return
        if current["started_this_month"]:
            db.execute(
                text("update business_cost_items set amount_cents = :amount where id = :id"),
                {"id": current["id"], "amount": amount_cents},
            )
            return
        db.execute(
            text(
                "update business_cost_items set ends_on = (" + _THIS_MONTH + " - interval '1 month')::date "
                "where id = :id"
            ),
            {"id": current["id"]},
        )
    db.execute(
        text(
            "insert into business_cost_items (business_id, label, amount_cents, kind, starts_on, stripe_subscription_id) "
            "values (:business_id, :label, :amount, 'monthly', " + _THIS_MONTH + ", :sub)"
        ),
        {
            "business_id": metadata["business_id"],
            "label": "Finance Premium" if metadata.get("product") == _FINANCE_PRODUCT else "Shop subscription",
            "amount": amount_cents,
            "sub": subscription_id,
        },
    )


def _credit_referral(db: Session, invoice: dict) -> None:
    """Whoever referred the shop earns 5% of every paid shop-subscription
    invoice, for as long as the shop keeps paying — never Finance Premium.
    Keyed on the business from the invoice's metadata rather than the stored
    subscription id: the first invoice can arrive before
    checkout.session.completed has stored it. A shop owner can't refer
    their own shop."""
    metadata = _invoice_subscription_metadata(invoice)
    amount_cents = round(invoice.get("amount_paid", 0) * _REFERRAL_SHARE)
    if metadata.get("product") == _FINANCE_PRODUCT or "business_id" not in metadata or amount_cents <= 0:
        return
    db.execute(
        text(
            "insert into reward_ledger (customer_id, source, stripe_invoice_id, amount_cents, currency) "
            "select p.id, 'referral', :invoice, :amount, :currency from businesses b "
            "join profiles p on p.referral_code = b.referred_by_code "
            "where b.id = :business_id and p.id <> b.owner_id "
            "on conflict (stripe_invoice_id) do nothing"
        ),
        {
            "invoice": invoice["id"],
            "amount": amount_cents,
            "currency": invoice["currency"].upper(),
            "business_id": metadata["business_id"],
        },
    )


def _scheduled_cancellation(subscription: dict) -> int | None:
    """Stripe documents cancel_at as the scheduled date but not that
    cancel_at_period_end fills it in; the period end (on the item since API
    2025-03-31, and the trial end during a trial) is the same moment."""
    if subscription.get("cancel_at"):
        return subscription["cancel_at"]
    if not subscription.get("cancel_at_period_end"):
        return None
    return subscription["items"]["data"][0]["current_period_end"]


def _handle_subscription_updated(db: Session, subscription: dict) -> None:
    """Records the main subscription's trial end and scheduled cancellation,
    and Finance Premium's scheduled cancellation. The main one is keyed on
    the business (metadata set at checkout), not the subscription id:
    `created` can arrive before checkout.session.completed has stored that
    id. A canceled subscription is left to the deleted handler — it may be
    an old one the business has since replaced."""
    if subscription["status"] in ("canceled", "incomplete_expired"):
        return
    metadata = subscription.get("metadata") or {}
    cancel_at = _from_unix(_scheduled_cancellation(subscription))
    if metadata.get("product") == _FINANCE_PRODUCT:
        db.execute(
            text("update business_finance_access set cancel_at = :cancel_at where stripe_subscription_id = :sub"),
            {"sub": subscription["id"], "cancel_at": cancel_at},
        )
        return
    if "business_id" not in metadata:
        return
    db.execute(
        text(
            "update business_subscriptions set stripe_subscription_id = :sub, "
            "trial_ends_at = :trial_ends_at, cancel_at = :cancel_at where business_id = :business_id"
        ),
        {
            "sub": subscription["id"],
            "trial_ends_at": _from_unix(subscription.get("trial_end")),
            "cancel_at": cancel_at,
            "business_id": metadata["business_id"],
        },
    )


def _handle_subscription_deleted(db: Session, subscription: dict) -> None:
    # Either Stripe gave up retrying (suspended_at already set by the first
    # failure — keep it) or the owner canceled and the paid period ran out
    # (starts the grace clock now).
    db.execute(
        text(
            "update business_subscriptions set status = 'canceled', suspended_at = coalesce(suspended_at, now()) "
            "where stripe_subscription_id = :sub"
        ),
        {"sub": subscription["id"]},
    )
    db.execute(
        text("update business_finance_access set subscription_status = 'canceled' where stripe_subscription_id = :sub"),
        {"sub": subscription["id"]},
    )
    # The last paid period usually ran into this month, so the cost stops
    # with last month — unless it only started this month.
    db.execute(
        text(
            "update business_cost_items set ends_on = greatest(starts_on, (" + _THIS_MONTH + " - interval '1 month')::date) "
            "where stripe_subscription_id = :sub and ends_on is null"
        ),
        {"sub": subscription["id"]},
    )


_WEBHOOK_HANDLERS = {
    "checkout.session.completed": _handle_checkout_completed,
    "invoice.payment_failed": _handle_invoice_payment_failed,
    "invoice.payment_succeeded": _handle_invoice_payment_succeeded,
    "customer.subscription.created": _handle_subscription_updated,
    "customer.subscription.updated": _handle_subscription_updated,
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
        # Since stripe-python 13 its objects are no longer dicts (no .get);
        # the handlers, like their tests, work on plain dicts.
        handler(db, event["data"]["object"].to_dict())

    db.execute(
        text("insert into stripe_events (id, type) values (:id, :type)"),
        {"id": event["id"], "type": event["type"]},
    )
    db.commit()
    return {"received": True}
