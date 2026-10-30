"""top-rated barbers ranking for business accounts only

Revision ID: e4a9c2f7b1d6
Revises: d2f6b8a3c5e7
Create Date: 2026-10-31 18:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'e4a9c2f7b1d6'
down_revision: Union[str, Sequence[str], None] = 'd2f6b8a3c5e7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.

    Shops use this ranking to find barbers to hire; customers mustn't get the
    data at all, so the check lives in the function rather than the app.
    plpgsql (not sql) so it can raise; ORDER BY 4 because `value` is also an
    output column name there and would be ambiguous.
    """
    op.execute(
        """
        drop function ranking_top_barbers();

        create function ranking_top_barbers()
        returns table(worker_profile_id uuid, username text, avatar_url text, value numeric)
        language plpgsql stable security definer set search_path = public, pg_temp as $$
        begin
            if not exists (select 1 from profiles where id = auth.uid() and role = 'business') then
                raise exception 'Only business accounts can see the barber ranking.' using errcode = '42501';
            end if;
            return query
                select w.profile_id, p.username, p.avatar_url, avg(r.worker_rating)
                from reviews r
                join workers w on w.id = r.worker_id
                join profiles p on p.id = w.profile_id
                where w.profile_id is not null and r.worker_rating is not null
                group by w.profile_id, p.username, p.avatar_url
                order by 4 desc limit 50;
        end;
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

        create function ranking_top_barbers()
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
