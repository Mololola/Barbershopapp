"""shop page branding: brand colour, cover photo, rating on businesses_public

Revision ID: d4a7e2c9f1b3
Revises: c3e8d51a7b92
Create Date: 2026-09-30 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd4a7e2c9f1b3'
down_revision: Union[str, Sequence[str], None] = 'c3e8d51a7b92'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Chosen by the owner from the app's curated palette; null means the
        -- app assigns one from the business id. Stored as hex (not a palette
        -- key) so the palette can change without a migration.
        alter table businesses
            add column brand_color text check (brand_color ~ '^#[0-9A-F]{6}$'),
            add column cover_url text;

        -- The shop page (what customers choose from) needs branding and the
        -- shop's rating. All public by nature, so safe on this view — see
        -- its comment. Appended at the end, so create or replace keeps the
        -- view's locked-down grants.
        create or replace view businesses_public as
        select
            b.id,
            b.owner_id,
            b.name,
            b.currency,
            b.created_at,
            b.logo_url,
            exists (select 1 from services s where s.business_id = b.id and s.is_active)
                and exists (select 1 from workers w where w.business_id = b.id and w.is_active)
                as is_bookable,
            b.brand_color,
            b.cover_url,
            (select round(avg(r.shop_rating), 1) from reviews r where r.business_id = b.id) as average_rating,
            (select count(*) from reviews r where r.business_id = b.id and r.shop_rating is not null)::int
                as review_count
        from businesses b
        where b.is_suspended = false;

        -- Never worked: authenticated has no UPDATE grant on
        -- is_quality_reviewer (e91a5c3f7d24), and a policy can't restore a
        -- revoked column. Admins promote through the backend instead
        -- (POST /admin/customers/{id}/quality-reviewer).
        drop policy "admin update quality reviewer flag" on profiles;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        create policy "admin update quality reviewer flag"
            on profiles for update
            using (exists (select 1 from profiles me where me.id = auth.uid() and me.is_admin = true));

        drop view businesses_public;
        create view businesses_public as
        select
            b.id,
            b.owner_id,
            b.name,
            b.currency,
            b.created_at,
            b.logo_url,
            exists (select 1 from services s where s.business_id = b.id and s.is_active)
                and exists (select 1 from workers w where w.business_id = b.id and w.is_active)
                as is_bookable
        from businesses b
        where b.is_suspended = false;
        revoke all on businesses_public from public, anon, authenticated;
        grant select on businesses_public to authenticated;

        alter table businesses drop column brand_color, drop column cover_url;
        """
    )
