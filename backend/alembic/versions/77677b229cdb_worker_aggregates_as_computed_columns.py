"""worker aggregates as computed columns (filterable/embeddable, not just RPC)

Revision ID: 77677b229cdb
Revises: e167a444c6c6
Create Date: 2026-08-19 00:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '77677b229cdb'
down_revision: Union[str, Sequence[str], None] = 'e167a444c6c6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.

    e167a444c6c6's worker_shops_worked_count/worker_average_rating took a
    plain `uuid` argument, callable only via `.rpc(...)`. The marketplace
    needs to both *filter* on these (rating >= X, shops worked >= Y) and
    embed them alongside a paginated `profiles` query in one round trip —
    neither is possible with a scalar-arg RPC function. Redefining them to
    take the `worker_profiles` row itself makes PostgREST expose them as
    computed columns on that table (`worker_profiles.worker_average_rating`
    in a select/filter string), which supports both.
    """
    op.execute(
        """
        drop function worker_average_rating(uuid);
        drop function worker_shops_worked_count(uuid);

        create or replace function worker_shops_worked_count(worker_profiles)
        returns int
        language sql stable security definer set search_path = public, pg_temp as $$
            select count(distinct business_id)::int from workers where workers.profile_id = $1.profile_id;
        $$;

        create or replace function worker_average_rating(worker_profiles)
        returns numeric
        language sql stable security definer set search_path = public, pg_temp as $$
            select avg(r.worker_rating) from reviews r
            join workers w on w.id = r.worker_id
            where w.profile_id = $1.profile_id;
        $$;

        revoke all on function worker_shops_worked_count(worker_profiles) from public, anon;
        revoke all on function worker_average_rating(worker_profiles) from public, anon;

        grant execute on function worker_shops_worked_count(worker_profiles) to authenticated;
        grant execute on function worker_average_rating(worker_profiles) to authenticated;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop function worker_average_rating(worker_profiles);
        drop function worker_shops_worked_count(worker_profiles);

        create or replace function worker_shops_worked_count(worker_profile_id uuid)
        returns int
        language sql stable security definer set search_path = public, pg_temp as $$
            select count(distinct business_id)::int from workers where workers.profile_id = worker_profile_id;
        $$;

        create or replace function worker_average_rating(worker_profile_id uuid)
        returns numeric
        language sql stable security definer set search_path = public, pg_temp as $$
            select avg(r.worker_rating) from reviews r
            join workers w on w.id = r.worker_id
            where w.profile_id = worker_profile_id;
        $$;

        revoke all on function worker_shops_worked_count(uuid) from public, anon;
        revoke all on function worker_average_rating(uuid) from public, anon;

        grant execute on function worker_shops_worked_count(uuid) to authenticated;
        grant execute on function worker_average_rating(uuid) to authenticated;
        """
    )
