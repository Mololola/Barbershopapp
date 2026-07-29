"""haircut designs and thumbnail bucket

Revision ID: 766be8cb9b71
Revises: c3d4fbf26e85
Create Date: 2026-07-29 03:03:05.316396

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '766be8cb9b71'
down_revision: Union[str, Sequence[str], None] = 'c3d4fbf26e85'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- parameters is schemaless on purpose — adding a new hair
        -- parameter later is a Dart-only change, not a migration.
        create table haircut_designs (
            id uuid primary key default gen_random_uuid(),
            owner_id uuid not null references profiles(id) on delete cascade,
            forked_from_id uuid references haircut_designs(id) on delete set null,
            name text not null,
            parameters jsonb not null,
            thumbnail_url text,
            is_public boolean not null default false,
            created_at timestamptz not null default now()
        );

        alter table haircut_designs enable row level security;

        create policy "owner select own designs"
            on haircut_designs for select
            using (auth.uid() = owner_id);

        create policy "anyone select public designs"
            on haircut_designs for select
            using (is_public = true);

        create policy "owner insert own designs"
            on haircut_designs for insert
            with check (auth.uid() = owner_id);

        create policy "owner update own designs"
            on haircut_designs for update
            using (auth.uid() = owner_id);

        create policy "owner delete own designs"
            on haircut_designs for delete
            using (auth.uid() = owner_id);

        -- Same shape as the avatars bucket (4c7963a698c7): path prefixed by
        -- auth.uid(), public read, owner-only write.
        insert into storage.buckets (id, name, public)
            values ('haircut-thumbnails', 'haircut-thumbnails', true)
            on conflict do nothing;

        create policy "authenticated upload own design thumbnail"
            on storage.objects for insert
            with check (
                bucket_id = 'haircut-thumbnails'
                and auth.uid()::text = (storage.foldername(name))[1]
            );

        create policy "authenticated update own design thumbnail"
            on storage.objects for update
            using (
                bucket_id = 'haircut-thumbnails'
                and auth.uid()::text = (storage.foldername(name))[1]
            );

        create policy "public read design thumbnails"
            on storage.objects for select
            using (bucket_id = 'haircut-thumbnails');
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop policy "public read design thumbnails" on storage.objects;
        drop policy "authenticated update own design thumbnail" on storage.objects;
        drop policy "authenticated upload own design thumbnail" on storage.objects;
        delete from storage.buckets where id = 'haircut-thumbnails';

        drop table haircut_designs;
        """
    )
