"""reward currencies and payout bank details

Revision ID: e2c4a8f6b1d3
Revises: d8b3f1a6c2e9
Create Date: 2026-10-07 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e2c4a8f6b1d3'
down_revision: Union[str, Sequence[str], None] = 'd8b3f1a6c2e9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Rewards stay in the currency they were earned in (the reviewed
        -- shop's, or the referred shop's invoice) and are never converted:
        -- someone earning in two countries holds two balances.
        alter table reward_ledger add column currency text check (char_length(currency) = 3);
        update reward_ledger l set currency = bz.currency
            from reviews r join bookings b on b.id = r.booking_id join businesses bz on bz.id = b.business_id
            where r.id = l.review_id;
        -- The only referral credit before this migration was a EUR invoice
        -- (backfilled by hand the day d8b3f1a6c2e9 shipped).
        update reward_ledger set currency = 'EUR' where source = 'referral';
        alter table reward_ledger alter column currency set not null;

        -- Every payout before this migration paid out GBP review rewards.
        alter table payout_requests add column currency text not null default 'GBP' check (char_length(currency) = 3);
        alter table payout_requests alter column currency drop default;

        -- Where the admin sends the money, copied from payout_details when
        -- the request is made, so a later edit can't redirect a request
        -- that is already queued. Null only on requests from before this.
        alter table payout_requests add column account_holder text;
        alter table payout_requests add column iban text;

        -- Requests now go through FastAPI, which checks the balance per
        -- currency under a lock; a direct insert could overdraw it.
        drop policy "requester insert own payout request" on payout_requests;

        -- One bank account per person. Written only by FastAPI (it
        -- validates the IBAN); readable only by its owner — the admin
        -- works from each request's own copy.
        create table payout_details (
            profile_id uuid primary key references profiles(id) on delete cascade,
            account_holder text not null,
            iban text not null,
            updated_at timestamptz not null default now()
        );

        alter table payout_details enable row level security;

        create policy "owner select own payout details"
            on payout_details for select
            using (auth.uid() = profile_id);
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop table payout_details;
        create policy "requester insert own payout request"
            on payout_requests for insert
            with check (auth.uid() = profile_id);
        alter table payout_requests drop column iban;
        alter table payout_requests drop column account_holder;
        alter table payout_requests drop column currency;
        alter table reward_ledger drop column currency;
        """
    )
