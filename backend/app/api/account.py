from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.auth import get_current_user_id
from app.core.rate_limit import rate_limit
from app.db.session import get_db

router = APIRouter()


def _block_reason(db: Session, user_id: str) -> str | None:
    """None means the account is clear to delete. A business owner can't
    self-delete out from under an active subscription (would orphan Stripe
    billing) or an upcoming booking a customer is relying on — both have to
    be resolved first, through the flows that already exist for them."""
    business = db.execute(
        text("select id from businesses where owner_id = :user_id"), {"user_id": user_id}
    ).mappings().first()
    if business is None:
        return None

    has_active_subscription = db.execute(
        # One already set to cancel at period end will never charge again.
        text(
            "select 1 from business_subscriptions "
            "where business_id = :business_id and status = 'active' and cancel_at is null"
        ),
        {"business_id": business["id"]},
    ).first()
    if has_active_subscription:
        return "Cancel your subscription before deleting your account."

    upcoming_bookings = db.execute(
        text(
            "select count(*) from bookings "
            "where business_id = :business_id and status = 'confirmed' and start_time > now()"
        ),
        {"business_id": business["id"]},
    ).scalar()
    if upcoming_bookings:
        plural = "s" if upcoming_bookings != 1 else ""
        return f"Resolve your {upcoming_bookings} upcoming booking{plural} before deleting your account."

    return None


@router.delete("/account", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(
    db: Session = Depends(get_db),
    _rate_limit: None = Depends(rate_limit("3/minute")),
    user_id: str = Depends(get_current_user_id),
) -> None:
    reason = _block_reason(db, user_id)
    if reason:
        raise HTTPException(status.HTTP_409_CONFLICT, reason)

    # Supabase's auth.* internal tables (identities, sessions, refresh_tokens,
    # mfa_factors, ...) all cascade from auth.users in its stock schema — this
    # is what the Admin API does internally. profiles.id also cascades from
    # auth.users(id), and everything else in the app cascades transitively
    # from profiles/businesses, so this one delete removes the account and
    # every row it owns app-wide.
    # Paid payouts are kept (tax records, migration e9a4c2f7b8d1); money not
    # yet paid out was offered to the user first and is given up.
    db.execute(
        text("delete from payout_requests where profile_id = :user_id and status <> 'paid'"),
        {"user_id": user_id},
    )
    db.execute(text("delete from auth.users where id = :user_id"), {"user_id": user_id})
    db.commit()


class UnpaidBalance(BaseModel):
    currency: str
    amount_cents: int


@router.get("/account/unpaid-rewards", response_model=list[UnpaidBalance])
def unpaid_rewards(
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
) -> list[UnpaidBalance]:
    """Rewards earned but not yet paid out (requested or not), per currency
    — what deleting the account would give up."""
    rows = db.execute(
        text(
            "select l.currency, l.earned - coalesce(p.paid, 0) as amount_cents "
            "from (select currency, sum(amount_cents) as earned from reward_ledger "
            "      where customer_id = :user_id group by currency) l "
            "left join (select currency, sum(amount_cents) as paid from payout_requests "
            "           where profile_id = :user_id and status = 'paid' group by currency) p "
            "  on p.currency = l.currency "
            "where l.earned - coalesce(p.paid, 0) > 0 order by l.currency"
        ),
        {"user_id": user_id},
    ).mappings().all()
    return [UnpaidBalance(**row) for row in rows]


class SignUpAvailabilityRequest(BaseModel):
    email: str
    username: str


class SignUpAvailabilityResponse(BaseModel):
    email_available: bool
    username_available: bool


# Unauthenticated by necessity (the caller has no account yet), and it does
# reveal whether an email is registered. That's accepted: usernames are
# public anyway, so a combined "email or username taken" message would hide
# nothing (an attacker just pairs the email with a random username), and
# Supabase's own signUp() leaks the same fact through its response shape.
# The real mitigation for email probing is the tight per-IP rate limit.
@router.post("/account/signup-availability", response_model=SignUpAvailabilityResponse)
def signup_availability(
    body: SignUpAvailabilityRequest,
    db: Session = Depends(get_db),
    _rate_limit: None = Depends(rate_limit("10/minute")),
) -> SignUpAvailabilityResponse:
    # Unconfirmed accounts count as taken too: Supabase won't create a
    # second account for the email either way, it just silently re-sends
    # the original confirmation.
    email_taken = db.execute(
        text("select 1 from auth.users where lower(email) = lower(:email)"),
        {"email": body.email.strip()},
    ).first()
    # A username is held either by a real profile or by a signup that hasn't
    # confirmed/first-signed-in yet — its profile row only gets inserted then
    # (see currentProfileProvider in the app), so until that happens the
    # username only exists in the auth user's metadata.
    username_taken = db.execute(
        text(
            "select 1 from profiles where lower(username) = lower(:username) "
            "union all "
            "select 1 from auth.users u "
            "where lower(u.raw_user_meta_data->>'username') = lower(:username) "
            "and not exists (select 1 from profiles p where p.id = u.id)"
        ),
        {"username": body.username.strip()},
    ).first()
    return SignUpAvailabilityResponse(email_available=not email_taken, username_available=not username_taken)
