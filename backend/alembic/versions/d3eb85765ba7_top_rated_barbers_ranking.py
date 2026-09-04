"""top-rated barbers ranking function

Revision ID: d3eb85765ba7
Revises: 6d3651e8cb11
Create Date: 2026-08-19 03:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd3eb85765ba7'
down_revision: Union[str, Sequence[str], None] = '6d3651e8cb11'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.

    worker_average_rating (77677b229cdb) computes one worker's rating as a
    computed column — the Rankings screen needs a ranked *list* instead,
    same shape and SECURITY DEFINER rationale as the other ranking_*
    functions (fe484555692e): averaged across every employment a person has
    had, career-wide, not scoped to one business.
    """
    op.execute(
        """
        create or replace function ranking_top_barbers()
        returns table(worker_profile_id uuid, username text, avatar_url text, value numeric)
        language sql stable security definer set search_path = public, pg_temp as $$
            select w.profile_id, p.username, p.avatar_url, avg(r.worker_rating) as value
            from reviews r
            join workers w on w.id = r.worker_id
            join profiles p on p.id = w.profile_id
            where w.profile_id is not null and r.worker_rating is not null
            group by w.profile_id, p.username, p.avatar_url
            order by value desc limit 50;
        $$;

        revoke all on function ranking_top_barbers() from public, anon;
        grant execute on function ranking_top_barbers() to authenticated;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop function ranking_top_barbers();
        """
    )
