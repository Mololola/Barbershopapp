"""profile display name and bio; let people delete their own avatar

Revision ID: d2f6b8a3c5e7
Revises: c8e2a4f6b1d3
Create Date: 2026-10-30 18:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'd2f6b8a3c5e7'
down_revision: Union[str, Sequence[str], None] = 'c8e2a4f6b1d3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Both optional and set by the owner through the existing "update own
        -- profile" policy. Null rather than '' when empty, so the app has one
        -- way to say "not set". The username stays the fixed handle: shops
        -- look people up by it to invite them as staff.
        alter table profiles
            add column display_name text check (char_length(display_name) between 1 and 40),
            add column bio text check (char_length(bio) between 1 and 160);

        -- Avatars are public by URL, so "Remove photo" has to delete the file,
        -- not just forget its URL. Same own-folder rule as upload and update.
        create policy "authenticated delete own avatar"
            on storage.objects for delete
            using (
                bucket_id = 'avatars'
                and auth.uid()::text = (storage.foldername(name))[1]
            );
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop policy "authenticated delete own avatar" on storage.objects;
        alter table profiles drop column display_name, drop column bio;
        """
    )
