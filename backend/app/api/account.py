from fastapi import APIRouter, Depends, HTTPException, status
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
        text("select 1 from business_subscriptions where business_id = :business_id and status = 'active'"),
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
    db.execute(text("delete from auth.users where id = :user_id"), {"user_id": user_id})
    db.commit()
