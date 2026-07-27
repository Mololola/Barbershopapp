"""create posts post_media likes comments tables and post-media bucket

Revision ID: 6892530b9406
Revises: 43caa76c09ea
Create Date: 2026-07-26 01:15:17.678830

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '6892530b9406'
down_revision: Union[str, Sequence[str], None] = '43caa76c09ea'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        create table posts (
            id uuid primary key default gen_random_uuid(),
            author_id uuid not null references profiles(id) on delete cascade,
            body text,
            created_at timestamptz not null default now()
        );

        create table post_media (
            id uuid primary key default gen_random_uuid(),
            post_id uuid not null references posts(id) on delete cascade,
            media_url text not null
        );

        create table likes (
            id uuid primary key default gen_random_uuid(),
            post_id uuid not null references posts(id) on delete cascade,
            profile_id uuid not null references profiles(id) on delete cascade,
            created_at timestamptz not null default now(),
            unique (post_id, profile_id)
        );

        create table comments (
            id uuid primary key default gen_random_uuid(),
            post_id uuid not null references posts(id) on delete cascade,
            author_id uuid not null references profiles(id) on delete cascade,
            body text not null,
            created_at timestamptz not null default now()
        );

        alter table posts enable row level security;
        alter table post_media enable row level security;
        alter table likes enable row level security;
        alter table comments enable row level security;

        -- All four: public-facing social content, same reasoning as reviews.
        create policy "authenticated read posts"
            on posts for select
            using (auth.uid() is not null);

        create policy "authenticated read post_media"
            on post_media for select
            using (auth.uid() is not null);

        create policy "authenticated read likes"
            on likes for select
            using (auth.uid() is not null);

        create policy "authenticated read comments"
            on comments for select
            using (auth.uid() is not null);

        create policy "author insert own post"
            on posts for insert
            with check (auth.uid() = author_id);

        create policy "author delete own post"
            on posts for delete
            using (auth.uid() = author_id);

        create policy "author insert own post media"
            on post_media for insert
            with check (
                exists (
                    select 1 from posts
                    where posts.id = post_media.post_id
                    and posts.author_id = auth.uid()
                )
            );

        create policy "user insert own like"
            on likes for insert
            with check (auth.uid() = profile_id);

        create policy "user delete own like"
            on likes for delete
            using (auth.uid() = profile_id);

        create policy "author insert own comment"
            on comments for insert
            with check (auth.uid() = author_id);

        create policy "author delete own comment"
            on comments for delete
            using (auth.uid() = author_id);

        insert into storage.buckets (id, name, public)
            values ('post-media', 'post-media', true)
            on conflict do nothing;

        -- Standard Supabase per-user-folder convention: objects must live
        -- under a path prefixed with the uploader's own uid.
        create policy "authenticated upload own post media"
            on storage.objects for insert
            with check (
                bucket_id = 'post-media'
                and auth.uid()::text = (storage.foldername(name))[1]
            );

        create policy "public read post media"
            on storage.objects for select
            using (bucket_id = 'post-media');
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop policy "public read post media" on storage.objects;
        drop policy "authenticated upload own post media" on storage.objects;
        delete from storage.buckets where id = 'post-media';

        drop table comments;
        drop table likes;
        drop table post_media;
        drop table posts;
        """
    )
