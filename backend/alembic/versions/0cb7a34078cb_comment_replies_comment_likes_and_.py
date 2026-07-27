"""comment replies, comment likes, and worker profile visibility

Revision ID: 0cb7a34078cb
Revises: 6892530b9406
Create Date: 2026-07-26 02:08:15.604101

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0cb7a34078cb'
down_revision: Union[str, Sequence[str], None] = '6892530b9406'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        alter table comments
            add column parent_comment_id uuid references comments(id) on delete cascade;

        create table comment_likes (
            id uuid primary key default gen_random_uuid(),
            comment_id uuid not null references comments(id) on delete cascade,
            profile_id uuid not null references profiles(id) on delete cascade,
            created_at timestamptz not null default now(),
            unique (comment_id, profile_id)
        );

        alter table comment_likes enable row level security;

        create policy "authenticated read comment_likes"
            on comment_likes for select
            using (auth.uid() is not null);

        create policy "user insert own comment like"
            on comment_likes for insert
            with check (auth.uid() = profile_id);

        create policy "user delete own comment like"
            on comment_likes for delete
            using (auth.uid() = profile_id);

        -- Was previously visible only when is_looking_for_work = true (so the
        -- worker-search feature wouldn't surface people not looking). A
        -- profile page needs to show the flag either way (including "not
        -- looking"), so broaden to any signed-in viewer. Safe:
        -- findWorkersByName in business_repository.dart already filters
        -- is_looking_for_work = true itself, so search results are
        -- unaffected by this RLS change.
        drop policy "public read looking-for-work worker profiles" on worker_profiles;

        create policy "authenticated read worker profiles"
            on worker_profiles for select
            using (auth.uid() is not null);
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop policy "authenticated read worker profiles" on worker_profiles;

        create policy "public read looking-for-work worker profiles"
            on worker_profiles for select
            using (is_looking_for_work = true);

        drop table comment_likes;

        alter table comments drop column parent_comment_id;
        """
    )
