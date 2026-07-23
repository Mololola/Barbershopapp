"""worker marketplace: worker_profiles, invitations, exclusivity

Revision ID: ba453d5e53aa
Revises: 8e861842851e
Create Date: 2026-07-23 18:20:23.381972

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ba453d5e53aa'
down_revision: Union[str, Sequence[str], None] = '8e861842851e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Nothing in `profiles` is sensitive (email lives in auth.users), so any
        -- authenticated user may look up any profile — needed so a business can
        -- resolve a username before inviting them as staff.
        create policy "authenticated read profiles"
            on profiles for select
            using (auth.uid() is not null);

        create table worker_profiles (
            profile_id uuid primary key references profiles(id) on delete cascade,
            bio text,
            city text,
            is_looking_for_work boolean not null default true,
            created_at timestamptz not null default now()
        );

        alter table worker_profiles enable row level security;

        create policy "owner select worker profile"
            on worker_profiles for select
            using (auth.uid() = profile_id);

        create policy "public read looking-for-work worker profiles"
            on worker_profiles for select
            using (is_looking_for_work = true);

        create policy "owner insert worker profile"
            on worker_profiles for insert
            with check (auth.uid() = profile_id);

        create policy "owner update worker profile"
            on worker_profiles for update
            using (auth.uid() = profile_id);

        alter table workers add column profile_id uuid references profiles(id);

        -- A profile can be active staff at only one business at a time,
        -- enforced by the database (same philosophy as the booking-slot
        -- EXCLUDE constraint) rather than trusted-to-app-code.
        create unique index workers_one_active_business_per_profile
            on workers (profile_id)
            where profile_id is not null and is_active;

        create table worker_invitations (
            id uuid primary key default gen_random_uuid(),
            business_id uuid not null references businesses(id) on delete cascade,
            worker_profile_id uuid not null references profiles(id) on delete cascade,
            status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
            created_at timestamptz not null default now(),
            responded_at timestamptz
        );

        alter table worker_invitations enable row level security;

        create policy "business select own invitations"
            on worker_invitations for select
            using (business_id in (select id from businesses where owner_id = auth.uid()));

        create policy "business insert invitations"
            on worker_invitations for insert
            with check (business_id in (select id from businesses where owner_id = auth.uid()));

        create policy "worker select own invitations"
            on worker_invitations for select
            using (auth.uid() = worker_profile_id);

        create policy "worker update own invitations"
            on worker_invitations for update
            using (auth.uid() = worker_profile_id);

        -- Accepting an invitation means the WORKER inserts their own `workers`
        -- row (see docs/architecture.md) — the existing owner-only policies on
        -- `workers` don't cover that, so add a narrowly-scoped one: only for
        -- themselves, and only against a business that actually invited them.
        create policy "worker insert own row via pending invitation"
            on workers for insert
            with check (
                profile_id = auth.uid()
                and exists (
                    select 1 from worker_invitations
                    where worker_invitations.business_id = workers.business_id
                    and worker_invitations.worker_profile_id = auth.uid()
                    and worker_invitations.status = 'pending'
                )
            );

        create policy "worker select own worker row"
            on workers for select
            using (auth.uid() = profile_id);
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop policy "worker select own worker row" on workers;
        drop policy "worker insert own row via pending invitation" on workers;
        drop table worker_invitations;
        drop index workers_one_active_business_per_profile;
        alter table workers drop column profile_id;
        drop table worker_profiles;
        drop policy "authenticated read profiles" on profiles;
        """
    )
