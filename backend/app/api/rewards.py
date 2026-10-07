import datetime
import uuid

import psycopg
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import get_current_user_id
from app.db.session import get_db
from app.models import Review, RewardLedger

router = APIRouter()

_AUTOMATIC_REWARD_CENTS = 200
_QUALITY_REWARD_CENTS = 300
_MONTHLY_CAP = 3


class RewardCreditResponse(BaseModel):
    credited: bool
    amount_cents: int
    reason: str | None = None


def _month_start(now: datetime.datetime) -> datetime.datetime:
    return now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)


def _tier_amount_cents(is_quality_reviewer: bool) -> int:
    return _QUALITY_REWARD_CENTS if is_quality_reviewer else _AUTOMATIC_REWARD_CENTS


def _is_duplicate_reward_error(exc: IntegrityError) -> bool:
    """True when the failure is reward_ledger.review_id's unique constraint
    — i.e. a concurrent request already credited this review between our
    "already credited?" check and this insert. Same reasoning as
    _map_booking_integrity_error in bookings.py: the application-level
    check is for the common case, the DB constraint is the actual
    guarantee, and a race on it should look like the idempotent response,
    not a raw 500."""
    return isinstance(exc.orig, psycopg.errors.UniqueViolation)


@router.post("/bookings/{booking_id}/credit-review-reward", response_model=RewardCreditResponse)
def credit_review_reward(
    booking_id: uuid.UUID,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
) -> RewardCreditResponse:
    """Called right after the customer's review write to Supabase succeeds
    (see docs/architecture.md — reviews themselves have no money invariant
    and stay a direct Supabase write; crediting a reward does, so it comes
    through here instead). Idempotent: retrying for an already-credited
    review is a benign no-op, not an error, so a network retry can't
    double-pay."""
    review = db.query(Review).filter(Review.booking_id == booking_id).first()
    if review is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No review for this booking")
    if str(review.customer_id) != user_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your review")

    already_credited = db.query(RewardLedger).filter(RewardLedger.review_id == review.id).first()
    if already_credited is not None:
        return RewardCreditResponse(credited=False, amount_cents=0, reason="already credited")

    month_start = _month_start(datetime.datetime.now(datetime.UTC))
    credited_this_month = (
        db.query(RewardLedger)
        .filter(
            RewardLedger.customer_id == review.customer_id,
            RewardLedger.source == "review",
            RewardLedger.created_at >= month_start,
        )
        .count()
    )
    if credited_this_month >= _MONTHLY_CAP:
        return RewardCreditResponse(credited=False, amount_cents=0, reason="monthly cap reached")

    is_quality_reviewer = db.execute(
        text("select is_quality_reviewer from profiles where id = :id"),
        {"id": review.customer_id},
    ).scalar()
    amount_cents = _tier_amount_cents(bool(is_quality_reviewer))
    # Paid in the reviewed shop's currency: £2 at a UK shop, €2 at a Spanish one.
    currency = db.execute(
        text("select bz.currency from bookings b join businesses bz on bz.id = b.business_id where b.id = :id"),
        {"id": booking_id},
    ).scalar()

    db.add(
        RewardLedger(
            customer_id=review.customer_id,
            source="review",
            review_id=review.id,
            amount_cents=amount_cents,
            currency=currency,
        )
    )
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        if _is_duplicate_reward_error(exc):
            return RewardCreditResponse(credited=False, amount_cents=0, reason="already credited")
        raise
    return RewardCreditResponse(credited=True, amount_cents=amount_cents)
