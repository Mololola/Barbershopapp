"""unpaid businesses: hidden from customers, 3-day grace after a lapse

Revision ID: f1c9a7d3e5b2
Revises: e8b2f6a1c4d7
Create Date: 2026-10-01 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f1c9a7d3e5b2'
down_revision: Union[str, Sequence[str], None] = 'e8b2f6a1c4d7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Visibility is computed from the subscription, not stored: a stored
        -- flag can only change when something runs, and the 3-day grace
        -- has no event at its end (and Render's sleeping dyno can't be
        -- trusted to run a job on time). Replaces businesses.is_suspended.
        --
        -- When a business stopped being shown to customers, or will stop;
        -- null while it's shown indefinitely (paying, or grandfathered).
        --   never subscribed: hidden from the moment it was created
        --   payment failed / canceled: shown for 3 more days after the lapse
        -- The deletion job erases a business 60 days after this moment.
        create function public.business_hidden_since(p_business_id uuid) returns timestamptz
            language sql stable security definer set search_path = ''
        as $$
            select case
                when s.business_id is null or (s.status = 'incomplete' and not s.grandfathered)
                    then b.created_at
                when s.status in ('suspended', 'canceled') and not s.grandfathered
                    then s.suspended_at + interval '3 days'
            end
            from public.businesses b
            left join public.business_subscriptions s on s.business_id = b.id
            where b.id = p_business_id;
        $$;
        revoke all on function public.business_hidden_since(uuid) from public, anon, authenticated;

        create function public.business_is_listed(p_business_id uuid) returns boolean
            language sql stable security definer set search_path = ''
        as $$
            select coalesce(public.business_hidden_since(p_business_id) > now(), true);
        $$;
        revoke all on function public.business_is_listed(uuid) from public, anon, authenticated;

        -- For the posts policy below: businesses' RLS is owner-only, so the
        -- reader can't see whether a post's author owns a hidden shop.
        create function public.is_hidden_shop_owner(p_profile_id uuid) returns boolean
            language sql stable security definer set search_path = ''
        as $$
            select exists (
                select 1 from public.businesses b
                where b.owner_id = p_profile_id and not public.business_is_listed(b.id)
            );
        $$;
        revoke all on function public.is_hidden_shop_owner(uuid) from public, anon;
        grant execute on function public.is_hidden_shop_owner(uuid) to authenticated;

        -- The 3-day clock runs from suspended_at; a voluntary cancellation
        -- never set it before now.
        update business_subscriptions set suspended_at = updated_at
            where status = 'canceled' and suspended_at is null;

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
        where public.business_is_listed(b.id);

        -- A hidden shop's posts leave the feed too; its owner still sees them.
        drop policy "authenticated read posts" on posts;
        create policy "authenticated read posts"
            on posts for select
            using (auth.uid() is not null and (author_id = auth.uid() or not public.is_hidden_shop_owner(author_id)));

        drop trigger businesses_guard_billing_columns on businesses;
        create or replace function public.businesses_guard_billing_columns() returns trigger
            language plpgsql
            set search_path = ''
        as $$
        begin
            if current_user <> 'authenticated' then
                return new;
            end if;
            if new.subscription_trial_ends_at is distinct from old.subscription_trial_ends_at
               and not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
                raise exception 'Only an admin can change a business''s trial.' using errcode = '42501';
            end if;
            return new;
        end;
        $$;
        create trigger businesses_guard_billing_columns
            before update of subscription_trial_ends_at on businesses
            for each row execute function public.businesses_guard_billing_columns();

        alter table businesses drop column is_suspended;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        alter table businesses add column is_suspended boolean not null default false;
        update businesses b set is_suspended = true
            from business_subscriptions s
            where s.business_id = b.id and s.status in ('suspended', 'canceled') and not s.grandfathered;

        drop trigger businesses_guard_billing_columns on businesses;
        create or replace function public.businesses_guard_billing_columns() returns trigger
            language plpgsql
            set search_path = ''
        as $$
        begin
            if current_user <> 'authenticated' then
                return new;
            end if;
            if new.is_suspended is distinct from old.is_suspended then
                raise exception 'Suspension is managed by billing.' using errcode = '42501';
            end if;
            if new.subscription_trial_ends_at is distinct from old.subscription_trial_ends_at
               and not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
                raise exception 'Only an admin can change a business''s trial.' using errcode = '42501';
            end if;
            return new;
        end;
        $$;
        create trigger businesses_guard_billing_columns
            before update of is_suspended, subscription_trial_ends_at on businesses
            for each row execute function public.businesses_guard_billing_columns();

        drop policy "authenticated read posts" on posts;
        create policy "authenticated read posts"
            on posts for select
            using (auth.uid() is not null);

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

        drop function public.is_hidden_shop_owner(uuid);
        drop function public.business_is_listed(uuid);
        drop function public.business_hidden_since(uuid);
        """
    )
