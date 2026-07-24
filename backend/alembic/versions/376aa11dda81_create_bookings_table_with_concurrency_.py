"""create bookings table with concurrency-safe exclusion constraint

Revision ID: 376aa11dda81
Revises: c305ecd7de27
Create Date: 2026-07-24 00:21:10.759855

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '376aa11dda81'
down_revision: Union[str, Sequence[str], None] = 'c305ecd7de27'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        create extension if not exists btree_gist;

        create table bookings (
            id uuid primary key default gen_random_uuid(),
            business_id uuid not null references businesses(id) on delete cascade,
            worker_id uuid not null references workers(id) on delete cascade,
            service_id uuid not null references services(id) on delete cascade,
            customer_id uuid not null references profiles(id) on delete cascade,
            start_time timestamptz not null,
            end_time timestamptz not null,
            status text not null default 'confirmed' check (status in ('confirmed', 'cancelled')),
            created_at timestamptz not null default now(),
            check (end_time > start_time)
        );

        -- The actual "never double-book a worker" guarantee (see
        -- docs/architecture.md). Partial on status='confirmed' so a
        -- cancelled booking doesn't keep blocking the slot. Writes to this
        -- table only ever come from FastAPI (see below), but the constraint
        -- protects correctness regardless of which process is inserting.
        alter table bookings
            add constraint no_overlapping_bookings
            exclude using gist (
                worker_id with =,
                tstzrange(start_time, end_time) with &&
            )
            where (status = 'confirmed');

        alter table bookings enable row level security;

        -- Deliberately SELECT-only: FastAPI writes via a direct Postgres
        -- connection (bypassing RLS entirely) after doing its own auth
        -- checks. With RLS enabled and no INSERT/UPDATE policy here,
        -- `authenticated` users are structurally unable to write bookings
        -- through Supabase directly — the backend is the only way in.
        create policy "customer select own bookings"
            on bookings for select
            using (auth.uid() = customer_id);

        create policy "business select own bookings"
            on bookings for select
            using (business_id in (select id from businesses where owner_id = auth.uid()));

        -- First real "customer browses other people's businesses" reads.
        -- Nothing sensitive in these three tables (unlike `businesses`,
        -- which has `phone` — handled via a view below).
        create policy "authenticated read services"
            on services for select
            using (auth.uid() is not null);

        create policy "authenticated read opening_hours"
            on opening_hours for select
            using (auth.uid() is not null);

        create policy "authenticated read workers"
            on workers for select
            using (auth.uid() is not null);

        -- `businesses` itself stays owner-only (has `phone`, spec says
        -- internal-only, RLS can't hide a single column) — browsing goes
        -- through this view instead, which excludes it.
        create view businesses_public as
            select id, owner_id, name, currency, created_at from businesses;

        -- Supabase auto-grants broad CRUD (including to `anon`) on every new
        -- public-schema object. That's harmless for real tables (RLS still
        -- gates every row/operation), but this view deliberately runs as its
        -- owner and bypasses `businesses`' RLS — without this revoke, the
        -- default grants would let anyone (even unauthenticated `anon`)
        -- update/delete `businesses` through the view, since simple views
        -- like this one are automatically updatable in Postgres.
        revoke all on businesses_public from public, anon, authenticated;
        grant select on businesses_public to authenticated;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop view businesses_public;
        drop policy "authenticated read workers" on workers;
        drop policy "authenticated read opening_hours" on opening_hours;
        drop policy "authenticated read services" on services;
        drop table bookings;
        """
    )
