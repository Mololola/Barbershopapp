"""business onboarding: structured addresses, setup completion, bookable flag

Revision ID: b7c41e9d2f60
Revises: a32a9a2ce22a
Create Date: 2026-09-24 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b7c41e9d2f60'
down_revision: Union[str, Sequence[str], None] = 'a32a9a2ce22a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Postcode + ISO country per location: enough to filter by area now
        -- and to geocode later for "near me" search. NOT NULL with no
        -- default: production had zero locations when this shipped, and a
        -- location without them is exactly what this migration exists to
        -- stop.
        alter table locations
            add column postcode text not null,
            add column country text not null check (char_length(country) = 2);

        -- Set once, by the owner, when the onboarding wizard finishes
        -- (details -> at least one service -> at least one staff member).
        -- Only drives the app's routing; whether customers can actually
        -- find the business is is_bookable below, which is computed live.
        alter table businesses add column setup_completed_at timestamptz;
        update businesses set setup_completed_at = now();

        -- A day that's open must have a real, non-inverted time range —
        -- the availability endpoint builds slots from these.
        alter table opening_hours add constraint opening_hours_valid_range check (
            is_closed or (open_time is not null and close_time is not null and close_time > open_time)
        );

        -- Customer browse lists only businesses someone could actually book
        -- right now. A column rather than a row filter on purpose: lookups
        -- by id (a customer's past booking, a worker resolving their
        -- employer mid-onboarding) must keep working for businesses that
        -- aren't bookable. New column is appended at the end, so create or
        -- replace keeps the view's existing locked-down grants.
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
                as is_bookable
        from businesses b
        where b.is_suspended = false;

        -- Same hole 'lock down profile privilege columns' (e91a5c3f7d24)
        -- closed on profiles: "owner update business" restricts rows, not
        -- columns, so an owner could PATCH is_suspended=false to un-suspend
        -- an unpaid account, or set their own subscription_trial_ends_at,
        -- straight through PostgREST. Guarded by a trigger rather than
        -- either of that migration's two layers: a column revoke is a no-op
        -- here (authenticated holds a table-wide UPDATE grant, which a
        -- column-level revoke doesn't override), and a businesses policy
        -- subquerying businesses for the old value is infinite RLS
        -- recursion. is_suspended is only ever written by the backend
        -- (postgres role); the trial only by the backend or an admin.
        create function public.businesses_guard_billing_columns() returns trigger
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
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop trigger businesses_guard_billing_columns on businesses;
        drop function public.businesses_guard_billing_columns();

        drop view businesses_public;
        create view businesses_public as
        select id, owner_id, name, currency, created_at, logo_url
        from businesses
        where is_suspended = false;
        revoke all on businesses_public from public, anon, authenticated;
        grant select on businesses_public to authenticated;

        alter table opening_hours drop constraint opening_hours_valid_range;
        alter table businesses drop column setup_completed_at;
        alter table locations drop column postcode, drop column country;
        """
    )
