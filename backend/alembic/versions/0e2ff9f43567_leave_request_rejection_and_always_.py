"""leave request rejection, and always-available marketplace visibility

Revision ID: 0e2ff9f43567
Revises: d3eb85765ba7
Create Date: 2026-09-04 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0e2ff9f43567'
down_revision: Union[str, Sequence[str], None] = 'd3eb85765ba7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.

    Two corrections from live testing:

    1. A leave request had no way to be declined — a worker's misclick had
       to be honored by the business, or sit pending forever. Widens the
       status check constraint to add 'rejected' (resolved, but the workers
       row stays untouched — see the Dart-side rejectLeaveRequest, which
       deliberately does NOT deactivate anything, unlike acknowledge).

    2. Accepting a job should not silently hide someone from other shops'
       searches — a worker stays discoverable/"looking for work" until they
       explicitly say otherwise, taking one job doesn't imply they're off
       the market for a second one. worker_is_actively_employed
       (d4911496e1da) was built for the opposite assumption and is now
       unused (the Dart-side marketplace query drops the filter in the same
       change) — dropped as dead code.
    """
    op.execute(
        """
        alter table worker_leave_requests drop constraint worker_leave_requests_status_check;
        alter table worker_leave_requests add constraint worker_leave_requests_status_check
            check (status in ('pending', 'acknowledged', 'rejected'));

        drop function worker_is_actively_employed(worker_profiles);
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
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

        alter table worker_leave_requests drop constraint worker_leave_requests_status_check;
        alter table worker_leave_requests add constraint worker_leave_requests_status_check
            check (status in ('pending', 'acknowledged'));
        """
    )
