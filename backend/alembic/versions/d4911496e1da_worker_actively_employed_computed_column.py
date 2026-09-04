"""worker actively-employed computed column, for excluding from the marketplace

Revision ID: d4911496e1da
Revises: 77677b229cdb
Create Date: 2026-08-19 01:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd4911496e1da'
down_revision: Union[str, Sequence[str], None] = '77677b229cdb'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.

    fetchWorkersLookingForWork only ever filtered on is_looking_for_work —
    a worker who accepts an invitation gets that flipped to false
    automatically (acceptInvitation), but nothing stops them manually
    flipping it back on from worker_profile_screen.dart while still
    actively employed, which would show them as "available" in another
    shop's marketplace while they're not. Same computed-column pattern as
    worker_shops_worked_count/worker_average_rating (77677b229cdb) so the
    marketplace query can filter it out in the same request.
    """
    op.execute(
        """
        create or replace function worker_is_actively_employed(worker_profiles)
        returns boolean
        language sql stable security definer set search_path = public, pg_temp as $$
            select exists (
                select 1 from workers
                where workers.profile_id = $1.profile_id and workers.is_active
            );
        $$;

        revoke all on function worker_is_actively_employed(worker_profiles) from public, anon;
        grant execute on function worker_is_actively_employed(worker_profiles) to authenticated;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop function worker_is_actively_employed(worker_profiles);
        """
    )
