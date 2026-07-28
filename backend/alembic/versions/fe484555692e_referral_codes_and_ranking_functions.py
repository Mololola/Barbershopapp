"""referral codes and ranking functions

Revision ID: fe484555692e
Revises: c86f1f99fe34
Create Date: 2026-07-27 21:45:06.963982

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'fe484555692e'
down_revision: Union[str, Sequence[str], None] = 'c86f1f99fe34'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Unique per-customer code, auto-generated — no application code
        -- needs to set it. Volatile default forces a table rewrite that
        -- computes a distinct value per existing row, not one shared value.
        alter table profiles
            add column referral_code text not null unique
            default upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));

        -- Nullable — a business may or may not have been referred. FK (not
        -- just a text match) so an invalid/typo'd code fails loudly at
        -- signup instead of silently never counting toward anyone's ranking.
        alter table businesses
            add column referred_by_code text references profiles(referral_code);

        -- SECURITY DEFINER: bookings/reviews are scoped by owner-only RLS
        -- (a customer reads only their own bookings, a business only its
        -- own), so a leaderboard genuinely needs to read across everyone —
        -- same rationale as the businesses_public view bypassing RLS.
        -- Explicit search_path is standard hardening for definer functions.
        create or replace function ranking_distinct_shops(window_start timestamptz)
        returns table(customer_id uuid, username text, avatar_url text, value bigint)
        language sql stable security definer set search_path = public, pg_temp as $$
            select b.customer_id, p.username, p.avatar_url, count(distinct b.business_id) as value
            from bookings b join profiles p on p.id = b.customer_id
            where b.status = 'completed' and (window_start is null or b.completed_at >= window_start)
            group by b.customer_id, p.username, p.avatar_url
            order by value desc limit 50;
        $$;

        create or replace function ranking_total_haircuts(window_start timestamptz)
        returns table(customer_id uuid, username text, avatar_url text, value bigint)
        language sql stable security definer set search_path = public, pg_temp as $$
            select b.customer_id, p.username, p.avatar_url, count(*) as value
            from bookings b join profiles p on p.id = b.customer_id
            where b.status = 'completed' and (window_start is null or b.completed_at >= window_start)
            group by b.customer_id, p.username, p.avatar_url
            order by value desc limit 50;
        $$;

        create or replace function ranking_haircut_types(window_start timestamptz)
        returns table(haircut_type text, value bigint)
        language sql stable security definer set search_path = public, pg_temp as $$
            select r.haircut_type, count(*) as value
            from reviews r
            where r.haircut_type is not null and (window_start is null or r.created_at >= window_start)
            group by r.haircut_type
            order by value desc limit 50;
        $$;

        -- All-time only, per spec — no window_start param.
        create or replace function ranking_referrals()
        returns table(customer_id uuid, username text, avatar_url text, value bigint)
        language sql stable security definer set search_path = public, pg_temp as $$
            select p.id, p.username, p.avatar_url, count(bz.id) as value
            from profiles p join businesses bz on bz.referred_by_code = p.referral_code
            where p.role = 'customer'
            group by p.id, p.username, p.avatar_url
            order by value desc limit 50;
        $$;

        revoke all on function ranking_distinct_shops(timestamptz) from public, anon;
        revoke all on function ranking_total_haircuts(timestamptz) from public, anon;
        revoke all on function ranking_haircut_types(timestamptz) from public, anon;
        revoke all on function ranking_referrals() from public, anon;

        grant execute on function ranking_distinct_shops(timestamptz) to authenticated;
        grant execute on function ranking_total_haircuts(timestamptz) to authenticated;
        grant execute on function ranking_haircut_types(timestamptz) to authenticated;
        grant execute on function ranking_referrals() to authenticated;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop function ranking_distinct_shops(timestamptz);
        drop function ranking_total_haircuts(timestamptz);
        drop function ranking_haircut_types(timestamptz);
        drop function ranking_referrals();

        alter table businesses drop column referred_by_code;
        alter table profiles drop column referral_code;
        """
    )
