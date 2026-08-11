"""fix profiles update grant to actually restrict privilege columns

Revision ID: b4e6f28a91dc
Revises: e91a5c3f7d24
Create Date: 2026-08-06 01:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b4e6f28a91dc'
down_revision: Union[str, Sequence[str], None] = 'e91a5c3f7d24'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- e91a5c3f7d24's column-level REVOKE was a no-op: `authenticated`
        -- holds a TABLE-level UPDATE grant on profiles (Supabase's default
        -- for every public-schema table — confirmed live via
        -- profiles.relacl showing "authenticated=arwdDxtm/postgres"), and
        -- a column-level REVOKE only removes column-specific grants; it
        -- doesn't reach a broader table-level one. The WITH CHECK added in
        -- that same migration is what's actually been blocking the
        -- escalation (verified live in a rolled-back transaction). This
        -- makes the grant layer real: drop the table-level UPDATE grant
        -- entirely and replace it with a column-level one covering every
        -- column except is_admin/is_quality_reviewer/role.
        revoke update on profiles from authenticated;
        grant update (id, username, avatar_url, created_at, referral_code) on profiles to authenticated;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        revoke update (id, username, avatar_url, created_at, referral_code) on profiles from authenticated;
        grant update on profiles to authenticated;
        """
    )
