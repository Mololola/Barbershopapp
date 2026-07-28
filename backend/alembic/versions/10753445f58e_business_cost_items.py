"""business cost items

Revision ID: 10753445f58e
Revises: 75f1a74951ff
Create Date: 2026-07-28 18:02:58.142040

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '10753445f58e'
down_revision: Union[str, Sequence[str], None] = '75f1a74951ff'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- One current recurring monthly figure per line item, not a
        -- per-month ledger — a business edits this list as costs change.
        create table business_cost_items (
            id uuid primary key default gen_random_uuid(),
            business_id uuid not null references businesses(id) on delete cascade,
            label text not null,
            amount_cents integer not null check (amount_cents >= 0),
            created_at timestamptz not null default now()
        );

        alter table business_cost_items enable row level security;

        create policy "owner select cost items"
            on business_cost_items for select
            using (business_id in (select id from businesses where owner_id = auth.uid()));

        create policy "owner insert cost items"
            on business_cost_items for insert
            with check (business_id in (select id from businesses where owner_id = auth.uid()));

        create policy "owner delete cost items"
            on business_cost_items for delete
            using (business_id in (select id from businesses where owner_id = auth.uid()));
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("drop table business_cost_items;")
