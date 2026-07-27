"""avatars storage bucket

Revision ID: 4c7963a698c7
Revises: 0cb7a34078cb
Create Date: 2026-07-26 03:06:28.623695

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '4c7963a698c7'
down_revision: Union[str, Sequence[str], None] = '0cb7a34078cb'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        insert into storage.buckets (id, name, public)
            values ('avatars', 'avatars', true)
            on conflict do nothing;

        create policy "authenticated upload own avatar"
            on storage.objects for insert
            with check (
                bucket_id = 'avatars'
                and auth.uid()::text = (storage.foldername(name))[1]
            );

        -- An avatar is uploaded to the same path repeatedly (upsert), unlike
        -- post images which each get a fresh path — needs update, not just insert.
        create policy "authenticated update own avatar"
            on storage.objects for update
            using (
                bucket_id = 'avatars'
                and auth.uid()::text = (storage.foldername(name))[1]
            );

        create policy "public read avatars"
            on storage.objects for select
            using (bucket_id = 'avatars');
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop policy "public read avatars" on storage.objects;
        drop policy "authenticated update own avatar" on storage.objects;
        drop policy "authenticated upload own avatar" on storage.objects;
        delete from storage.buckets where id = 'avatars';
        """
    )
