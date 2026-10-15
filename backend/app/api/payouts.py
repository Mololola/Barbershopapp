import re

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.auth import get_current_user_id
from app.db.session import get_db

router = APIRouter()


class PayoutDetailsRequest(BaseModel):
    account_holder: str = Field(min_length=2, max_length=100)
    iban: str


class PayoutRequestCreate(BaseModel):
    amount_cents: int = Field(gt=0)
    currency: str = Field(pattern=r"^[A-Z]{3}$")


def normalize_iban(raw: str) -> str | None:
    """The IBAN without spaces, upper-cased, or None if it fails the ISO
    13616 check digits — catches nearly every typo before the admin tries
    to pay into it. UK accounts have IBANs too, so one format covers both
    countries."""
    iban = re.sub(r"\s", "", raw).upper()
    if not re.fullmatch(r"[A-Z]{2}\d{2}[A-Z0-9]{11,30}", iban):
        return None
    rearranged = iban[4:] + iban[:4]
    digits = "".join(str(int(char, 36)) for char in rearranged)
    return iban if int(digits) % 97 == 1 else None


@router.post("/me/payout-details", status_code=status.HTTP_204_NO_CONTENT)
def save_payout_details(
    body: PayoutDetailsRequest,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
) -> None:
    iban = normalize_iban(body.iban)
    if iban is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "That IBAN isn't valid — check it and try again.")
    db.execute(
        text(
            "insert into payout_details (profile_id, account_holder, iban) values (:id, :holder, :iban) "
            "on conflict (profile_id) do update set account_holder = :holder, iban = :iban, updated_at = now()"
        ),
        {"id": user_id, "holder": body.account_holder.strip(), "iban": iban},
    )
    db.commit()


@router.post("/me/payout-requests", status_code=status.HTTP_201_CREATED)
def request_payout(
    body: PayoutRequestCreate,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
) -> None:
    # Locking the requester's profile row serializes their requests, so two
    # at once can't both pass the balance check and overdraw it.
    db.execute(text("select 1 from profiles where id = :id for update"), {"id": user_id})
    details = db.execute(
        text("select account_holder, iban from payout_details where profile_id = :id"), {"id": user_id}
    ).first()
    if details is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Add your bank details first.")
    available = db.execute(
        text(
            "select (select coalesce(sum(amount_cents), 0) from reward_ledger "
            "        where customer_id = :id and currency = :currency) "
            "     - (select coalesce(sum(amount_cents), 0) from payout_requests "
            "        where profile_id = :id and currency = :currency and status <> 'rejected')"
        ),
        {"id": user_id, "currency": body.currency},
    ).scalar()
    if body.amount_cents > available:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "That's more than your available balance.")
    db.execute(
        text(
            "insert into payout_requests (profile_id, requester_username, amount_cents, currency, account_holder, iban) "
            "select :id, username, :amount, :currency, :holder, :iban from profiles where id = :id"
        ),
        {
            "id": user_id,
            "amount": body.amount_cents,
            "currency": body.currency,
            "holder": details.account_holder,
            "iban": details.iban,
        },
    )
    db.commit()
