"""reward ledger and admin flags

Revision ID: 75f1a74951ff
Revises: fe484555692e
Create Date: 2026-07-28 15:55:17.801936

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '75f1a74951ff'
down_revision: Union[str, Sequence[str], None] = 'fe484555692e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        alter table profiles add column is_admin boolean not null default false;
        alter table profiles add column is_quality_reviewer boolean not null default false;

        -- Self-referencing: lets an admin update any profile's
        -- is_quality_reviewer. Only accounts flipped to is_admin=true via
        -- direct DB access (never reachable through the app) gain this —
        -- same trust boundary as any admin.
        create policy "admin update quality reviewer flag"
            on profiles for update
            using (
                exists (
                    select 1 from profiles me
                    where me.id = auth.uid() and me.is_admin = true
                )
            );

        create table reward_ledger (
            id uuid primary key default gen_random_uuid(),
            customer_id uuid not null references profiles(id) on delete cascade,
            source text not null default 'review' check (source in ('review', 'referral')),
            review_id uuid unique references reviews(id) on delete cascade,
            amount_cents integer not null check (amount_cents >= 0),
            created_at timestamptz not null default now()
        );

        alter table reward_ledger enable row level security;

        create policy "authenticated read own reward_ledger"
            on reward_ledger for select
            using (auth.uid() = customer_id);
        -- No insert/update/delete policy — only FastAPI (bypasses RLS via
        -- its postgres-role connection) ever writes this table.
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop table reward_ledger;
        drop policy "admin update quality reviewer flag" on profiles;
        alter table profiles drop column is_quality_reviewer;
        alter table profiles drop column is_admin;
        """
    )
