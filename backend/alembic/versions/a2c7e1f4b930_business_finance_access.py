"""business finance access (one-off unlock + free trial)

Revision ID: a2c7e1f4b930
Revises: 5ff57731d816
Create Date: 2026-07-29 15:40:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a2c7e1f4b930'
down_revision: Union[str, Sequence[str], None] = '5ff57731d816'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Unlike business_subscriptions, this is a one-off payment, not a
        -- recurring one: once paid_at is set it never expires. A business
        -- may instead be in a one-month free trial (trial_started_at /
        -- trial_ends_at) before ever paying — "unlocked" is computed as
        -- grandfathered OR paid OR still within the trial window, entirely
        -- client-side (see mobile/lib/features/business/domain/
        -- business_finance_access.dart), same pattern as
        -- BusinessSubscription.graceDaysRemaining. No status column and no
        -- scheduled job needed since there's no suspend/delete behavior.
        create table business_finance_access (
            id uuid primary key default gen_random_uuid(),
            business_id uuid not null unique references businesses(id) on delete cascade,
            grandfathered boolean not null default false,
            trial_started_at timestamptz,
            trial_ends_at timestamptz,
            paid_at timestamptz,
            amount_cents integer not null default 4500,
            created_at timestamptz not null default now(),
            updated_at timestamptz not null default now()
        );

        alter table business_finance_access enable row level security;

        create policy "owner select own finance access"
            on business_finance_access for select
            using (business_id in (select id from businesses where owner_id = auth.uid()));
        -- No insert/update/delete policy — only FastAPI (service-role)
        -- ever writes this table, same reasoning as business_subscriptions.

        -- Grandfather every pre-billing business in as permanently
        -- unlocked, so existing test data (which already used the finance
        -- tool for free per P2M3) keeps working.
        insert into business_finance_access (business_id, grandfathered)
            select id, true from businesses;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("drop table business_finance_access;")
