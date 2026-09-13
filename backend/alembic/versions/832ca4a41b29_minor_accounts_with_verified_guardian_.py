"""minor accounts with verified guardian consent

Revision ID: 832ca4a41b29
Revises: 0e2ff9f43567
Create Date: 2026-09-13 23:15:43.551977

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '832ca4a41b29'
down_revision: Union[str, Sequence[str], None] = '0e2ff9f43567'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        alter table profiles add column date_of_birth date;

        -- No account below 13 at all, in either country — the UK's own
        -- Article 8 floor (below which nobody, parent or not, can consent
        -- to a child's data processing). Existing rows have no
        -- date_of_birth and are grandfathered through (null is allowed).
        alter table profiles add constraint profiles_minimum_age_check
            check (date_of_birth is null or date_of_birth <= (current_date - interval '13 years')::date);

        -- A minor can only ever be a customer — no business ownership, no
        -- employment relationships, no subscription billing exposure.
        alter table profiles add constraint profiles_minor_role_check
            check (
                date_of_birth is null
                or date_of_birth <= (current_date - interval '18 years')::date
                or role = 'customer'
            );

        -- Same reasoning and exact pattern as e91a5c3f7d24's lock on
        -- is_admin/is_quality_reviewer/role: date_of_birth now gates real
        -- feature access (see the policies below), so it has to be set
        -- once at signup and never self-editable afterward, or the whole
        -- restriction is defeated by a raw PostgREST PATCH.
        revoke update (date_of_birth) on profiles from authenticated;

        drop policy "update own profile" on profiles;

        create policy "update own profile"
            on profiles for update
            using (auth.uid() = id)
            with check (
                auth.uid() = id
                and is_admin = (select p.is_admin from profiles p where p.id = auth.uid())
                and is_quality_reviewer = (select p.is_quality_reviewer from profiles p where p.id = auth.uid())
                and role = (select p.role from profiles p where p.id = auth.uid())
                and date_of_birth is not distinct from (select p.date_of_birth from profiles p where p.id = auth.uid())
            );

        -- Row-arg computed column (PostgREST auto-exposes as
        -- profile.is_minor in .select() strings) — pure arithmetic on the
        -- row's own already-visible column, so no security definer needed
        -- the way the cross-table worker_* functions require.
        create or replace function profile_is_minor(p profiles) returns boolean
            language sql
            stable
            as $$
                select p.date_of_birth is not null and p.date_of_birth > (current_date - interval '18 years')::date;
            $$;

        grant execute on function profile_is_minor(profiles) to authenticated;

        -- The actual verifiable-consent mechanism: a minor invites a
        -- guardian by email; the invited adult confirms explicit consent
        -- language from their own account. Mirrors worker_invitations'
        -- invite-by-identifier shape.
        create table profile_guardian_links (
            id uuid primary key default gen_random_uuid(),
            minor_profile_id uuid not null references profiles(id) on delete cascade,
            guardian_profile_id uuid references profiles(id) on delete cascade,
            guardian_email text not null,
            status text not null default 'pending' check (status in ('pending', 'confirmed')),
            consented_at timestamptz,
            created_at timestamptz not null default now()
        );

        alter table profile_guardian_links enable row level security;

        create unique index profile_guardian_links_one_confirmed_per_minor
            on profile_guardian_links (minor_profile_id)
            where (status = 'confirmed');

        create policy "minor select own guardian links"
            on profile_guardian_links for select
            using (auth.uid() = minor_profile_id);

        create policy "minor insert own guardian invite"
            on profile_guardian_links for insert
            with check (auth.uid() = minor_profile_id);

        create policy "invited guardian select their invite"
            on profile_guardian_links for select
            using (guardian_email = auth.email());

        create policy "invited guardian confirms"
            on profile_guardian_links for update
            using (guardian_email = auth.email() and status = 'pending')
            with check (
                guardian_profile_id = auth.uid()
                and status = 'confirmed'
                and guardian_email = (select l.guardian_email from profile_guardian_links l where l.id = profile_guardian_links.id)
                and minor_profile_id = (select l.minor_profile_id from profile_guardian_links l where l.id = profile_guardian_links.id)
                and not exists (select 1 from profiles p where p.id = auth.uid() and profile_is_minor(p))
            );

        -- Feature restrictions for an unconsented-or-restricted minor:
        -- no DMs, no posting/likes/comments, no opting into the worker
        -- marketplace. Bookings/reviews/browsing are deliberately left
        -- untouched — no in-app payment is involved in a booking, so
        -- there's no money-flow risk there to restrict.
        drop policy "participant insert own conversations" on conversations;

        create policy "participant insert own conversations"
            on conversations for insert
            with check (
                (auth.uid() = participant_a_id or auth.uid() = participant_b_id)
                and not exists (select 1 from profiles p where p.id = participant_a_id and profile_is_minor(p))
                and not exists (select 1 from profiles p where p.id = participant_b_id and profile_is_minor(p))
            );

        drop policy "author insert own post" on posts;

        create policy "author insert own post"
            on posts for insert
            with check (
                auth.uid() = author_id
                and not exists (select 1 from profiles p where p.id = auth.uid() and profile_is_minor(p))
            );

        drop policy "user insert own like" on likes;

        create policy "user insert own like"
            on likes for insert
            with check (
                auth.uid() = profile_id
                and not exists (select 1 from profiles p where p.id = auth.uid() and profile_is_minor(p))
            );

        drop policy "author insert own comment" on comments;

        create policy "author insert own comment"
            on comments for insert
            with check (
                auth.uid() = author_id
                and not exists (select 1 from profiles p where p.id = auth.uid() and profile_is_minor(p))
            );

        drop policy "owner insert worker profile" on worker_profiles;

        create policy "owner insert worker profile"
            on worker_profiles for insert
            with check (
                auth.uid() = profile_id
                and not exists (select 1 from profiles p where p.id = auth.uid() and profile_is_minor(p))
            );
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop policy "owner insert worker profile" on worker_profiles;
        create policy "owner insert worker profile"
            on worker_profiles for insert
            with check (auth.uid() = profile_id);

        drop policy "author insert own comment" on comments;
        create policy "author insert own comment"
            on comments for insert
            with check (auth.uid() = author_id);

        drop policy "user insert own like" on likes;
        create policy "user insert own like"
            on likes for insert
            with check (auth.uid() = profile_id);

        drop policy "author insert own post" on posts;
        create policy "author insert own post"
            on posts for insert
            with check (auth.uid() = author_id);

        drop policy "participant insert own conversations" on conversations;
        create policy "participant insert own conversations"
            on conversations for insert
            with check (auth.uid() = participant_a_id or auth.uid() = participant_b_id);

        drop table profile_guardian_links;

        drop function profile_is_minor(profiles);

        drop policy "update own profile" on profiles;
        create policy "update own profile"
            on profiles for update
            using (auth.uid() = id)
            with check (
                auth.uid() = id
                and is_admin = (select p.is_admin from profiles p where p.id = auth.uid())
                and is_quality_reviewer = (select p.is_quality_reviewer from profiles p where p.id = auth.uid())
                and role = (select p.role from profiles p where p.id = auth.uid())
            );

        grant update (date_of_birth) on profiles to authenticated;

        alter table profiles drop constraint profiles_minor_role_check;
        alter table profiles drop constraint profiles_minimum_age_check;
        alter table profiles drop column date_of_birth;
        """
    )
