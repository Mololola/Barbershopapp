"""business logo url

Revision ID: 1409471fb0ca
Revises: 4c7963a698c7
Create Date: 2026-07-27 02:18:28.162348

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '1409471fb0ca'
down_revision: Union[str, Sequence[str], None] = '4c7963a698c7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        alter table businesses add column logo_url text;

        -- New column appended at the end — CREATE OR REPLACE VIEW can only
        -- add columns after the existing ones, not insert them positionally.
        create or replace view businesses_public as
            select id, owner_id, name, currency, created_at, logo_url from businesses;

        -- Re-assert (CREATE OR REPLACE doesn't necessarily re-trigger
        -- Supabase's default-grant behavior, but doesn't hurt to restate it —
        -- see the original view's migration for why this exists at all).
        revoke all on businesses_public from public, anon, authenticated;
        grant select on businesses_public to authenticated;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        create or replace view businesses_public as
            select id, owner_id, name, currency, created_at from businesses;

        revoke all on businesses_public from public, anon, authenticated;
        grant select on businesses_public to authenticated;

        alter table businesses drop column logo_url;
        """
    )
