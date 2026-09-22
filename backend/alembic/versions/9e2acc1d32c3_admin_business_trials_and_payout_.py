"""admin business trials and payout request queue

Revision ID: 9e2acc1d32c3
Revises: 60c7bf238337
Create Date: 2026-09-22 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '9e2acc1d32c3'
down_revision: Union[str, Sequence[str], None] = '60c7bf238337'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Admin-granted, per-business — not automatic. Named distinctly
        -- from business_finance_access's own trial_started_at/trial_ends_at
        -- (a different, unrelated trial on a different table).
        alter table businesses add column subscription_trial_ends_at timestamptz;

        -- businesses/business_subscriptions RLS is owner-only today — an
        -- admin can't read a business they don't own, let alone update
        -- one. These are additive permissive policies (OR'd with the
        -- existing owner ones), same exists-subquery shape as the
        -- "admin update quality reviewer flag" policy on profiles.
        create policy "admin select all businesses"
            on businesses for select
            using (
                exists (select 1 from profiles me where me.id = auth.uid() and me.is_admin = true)
            );

        create policy "admin update businesses"
            on businesses for update
            using (
                exists (select 1 from profiles me where me.id = auth.uid() and me.is_admin = true)
            );

        create policy "admin select all business_subscriptions"
            on business_subscriptions for select
            using (
                exists (select 1 from profiles me where me.id = auth.uid() and me.is_admin = true)
            );

        -- A lightweight coordination record, not a ledger — the admin
        -- review step is the actual safety net, so there's deliberately no
        -- amount-vs-balance check here (see reward_ledger's own
        -- amount_cents >= 0 constraint, which stays untouched: this table
        -- never writes to it, "available balance" is computed by reading
        -- both at query time).
        create table payout_requests (
            id uuid primary key default gen_random_uuid(),
            profile_id uuid not null references profiles(id) on delete cascade,
            amount_cents integer not null check (amount_cents > 0),
            status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'paid')),
            requested_at timestamptz not null default now(),
            resolved_at timestamptz,
            admin_note text
        );

        alter table payout_requests enable row level security;

        create policy "requester select own payout requests"
            on payout_requests for select
            using (auth.uid() = profile_id);

        create policy "requester insert own payout request"
            on payout_requests for insert
            with check (auth.uid() = profile_id);

        create policy "admin select all payout requests"
            on payout_requests for select
            using (
                exists (select 1 from profiles me where me.id = auth.uid() and me.is_admin = true)
            );

        create policy "admin update payout requests"
            on payout_requests for update
            using (
                exists (select 1 from profiles me where me.id = auth.uid() and me.is_admin = true)
            );
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop table payout_requests;
        drop policy "admin select all business_subscriptions" on business_subscriptions;
        drop policy "admin update businesses" on businesses;
        drop policy "admin select all businesses" on businesses;
        alter table businesses drop column subscription_trial_ends_at;
        """
    )
