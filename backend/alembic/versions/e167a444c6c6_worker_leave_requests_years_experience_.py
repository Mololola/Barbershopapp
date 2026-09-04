"""worker leave requests, years experience, pinned posts, conversation types, worker aggregates

Revision ID: e167a444c6c6
Revises: a3e69b4d0f7c
Create Date: 2026-08-19 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e167a444c6c6'
down_revision: Union[str, Sequence[str], None] = 'a3e69b4d0f7c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Structured field for the marketplace's "years of experience"
        -- filter — previously only free-text `bio`. Nullable: existing
        -- worker profiles have no value to backfill.
        alter table worker_profiles add column years_experience integer;

        -- Portfolio posts on the marketplace candidate detail view — a
        -- worker's own curated highlights, separate from their chronological
        -- feed. `posts` never had an update policy at all (only
        -- select/insert/delete), so this needs a new one.
        alter table posts add column is_pinned boolean not null default false;

        create policy "author update own post"
            on posts for update
            using (auth.uid() = author_id)
            with check (auth.uid() = author_id);

        -- A worker leaving is no longer unilateral (see the Dart-side change
        -- from `leaveCurrentJob` to `requestLeave`): this row is the pending
        -- request, resolved by the business acknowledging it. business_name
        -- denormalized for the same reason as workers.business_name and
        -- worker_invitations.business_name (658403671135, c305ecd7de27) —
        -- lets the worker display who they asked to leave without needing
        -- cross-table RLS read access to `businesses`.
        create table worker_leave_requests (
            id uuid primary key default gen_random_uuid(),
            worker_id uuid not null references workers(id) on delete cascade,
            business_id uuid not null references businesses(id) on delete cascade,
            worker_profile_id uuid not null references profiles(id) on delete cascade,
            business_name text not null,
            status text not null default 'pending' check (status in ('pending', 'acknowledged')),
            requested_at timestamptz not null default now(),
            resolved_at timestamptz
        );

        alter table worker_leave_requests enable row level security;

        create policy "worker select own leave requests"
            on worker_leave_requests for select
            using (auth.uid() = worker_profile_id);

        -- WITH CHECK ties worker_id/business_id together and to the caller,
        -- not just worker_profile_id — a worker could otherwise file a leave
        -- request against a workers row (and business) that isn't theirs.
        create policy "worker insert own leave requests"
            on worker_leave_requests for insert
            with check (
                worker_profile_id = auth.uid()
                and exists (
                    select 1 from workers
                    where workers.id = worker_id
                    and workers.profile_id = auth.uid()
                    and workers.business_id = worker_leave_requests.business_id
                )
            );

        create policy "business select own leave requests"
            on worker_leave_requests for select
            using (business_id in (select id from businesses where owner_id = auth.uid()));

        create policy "business acknowledge own leave requests"
            on worker_leave_requests for update
            using (business_id in (select id from businesses where owner_id = auth.uid()))
            with check (business_id in (select id from businesses where owner_id = auth.uid()));

        -- Personal vs business inbox: the existing unique constraint allows
        -- exactly one conversation ever between any two people, so a
        -- business reaching out about work and a pre-existing personal
        -- thread with the same person couldn't coexist. Widen the key to
        -- include type instead of relaxing the constraint away entirely.
        alter table conversations add column type text not null default 'personal'
            check (type in ('personal', 'business'));

        alter table conversations
            drop constraint conversations_participant_a_id_participant_b_id_key;

        alter table conversations
            add constraint conversations_participant_a_id_participant_b_id_type_key
            unique (participant_a_id, participant_b_id, type);

        -- SECURITY DEFINER for the same reason as the ranking_* functions
        -- (fe484555692e): a business browsing the marketplace needs an
        -- aggregate about a worker it has no direct RLS relationship with,
        -- without exposing row-level employment/review data across that
        -- boundary. Both return null (no rows) rather than erroring.
        create or replace function worker_shops_worked_count(worker_profile_id uuid)
        returns int
        language sql stable security definer set search_path = public, pg_temp as $$
            select count(distinct business_id)::int from workers where workers.profile_id = worker_profile_id;
        $$;

        -- Averages across every employment the person has ever had (reviews
        -- join through workers on profile_id, not a single workers.id) —
        -- worker_rating is nullable (reviews' "omit a rating" flow), so
        -- avg() already ignores unrated reviews correctly on its own.
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


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop function worker_average_rating(uuid);
        drop function worker_shops_worked_count(uuid);

        alter table conversations
            drop constraint conversations_participant_a_id_participant_b_id_type_key;

        alter table conversations
            add constraint conversations_participant_a_id_participant_b_id_key
            unique (participant_a_id, participant_b_id);

        alter table conversations drop column type;

        drop table worker_leave_requests;

        drop policy "author update own post" on posts;
        alter table posts drop column is_pinned;

        alter table worker_profiles drop column years_experience;
        """
    )
