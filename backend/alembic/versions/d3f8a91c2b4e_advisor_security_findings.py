"""fix supabase advisor security findings

Revision ID: d3f8a91c2b4e
Revises: f6b1c4d0e7a2
Create Date: 2026-08-05 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd3f8a91c2b4e'
down_revision: Union[str, Sequence[str], None] = 'f6b1c4d0e7a2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Advisor: "RLS Disabled in Public" on alembic_version. Alembic's
        -- own bookkeeping table (one row: the current migration version) —
        -- no client or API consumer has any legitimate reason to touch it,
        -- only this migration tool via its direct (RLS-bypassing) postgres
        -- connection. Enabling RLS with zero policies blocks it from
        -- PostgREST entirely without affecting Alembic itself.
        alter table alembic_version enable row level security;

        -- Advisor: "Security Definer View" on businesses_public. This is
        -- intentional, not an oversight: businesses' own RLS is
        -- owner-select-only (see 8cf8327de9f9), so customer browsing has
        -- no rows to see there at all. businesses_public deliberately
        -- bypasses that RLS to expose a hand-picked, non-sensitive column
        -- subset (id, owner_id, name, currency, created_at, logo_url —
        -- notably not `phone` or anything financial) to any authenticated
        -- user, with grants locked down separately (revoke all; grant
        -- select to authenticated only). Setting security_invoker=true
        -- would make the view respect the underlying owner-only RLS and
        -- break browsing entirely, so that's not a fix — this is a
        -- reviewed, accepted design, documented here so it reads as a
        -- decision rather than a gap next time the Advisor (or a person)
        -- flags it.
        comment on view businesses_public is
            'Deliberately bypasses businesses RLS (owner-only) to expose a '
            'reviewed, non-sensitive column subset for customer browsing. '
            'Grants are locked down explicitly (see 5ff57731d816) — do not '
            'add columns here without checking they are safe to expose to '
            'any authenticated user.';
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        comment on view businesses_public is null;
        alter table alembic_version disable row level security;
        """
    )
