"""allow video posts: media_type column + bucket video mime types

Revision ID: d7f3a92c1e58
Revises: c8a1f5d47b6e
Create Date: 2026-08-06 13:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd7f3a92c1e58'
down_revision: Union[str, Sequence[str], None] = 'c8a1f5d47b6e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- post_media had no type discriminator — the app rendered every
        -- media_url as an <img>, which is fine for images but would just
        -- show a broken image for a video. default 'image' backfills every
        -- existing row correctly, since only images were ever uploadable
        -- before this migration.
        alter table post_media add column media_type text not null default 'image'
            check (media_type in ('image', 'video'));

        -- 50 MiB comfortably fits a compressed ~1-minute clip while still
        -- bounding uploads — the app enforces the actual 1-minute cap
        -- client-side (Supabase Storage has no concept of video duration),
        -- this is just the size backstop, same reasoning as the earlier
        -- image-only cap (c8a1f5d47b6e).
        update storage.buckets
        set file_size_limit = 52428800, -- 50 MiB
            allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime']
        where id = 'post-media';
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        update storage.buckets
        set file_size_limit = 10485760,
            allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
        where id = 'post-media';

        alter table post_media drop column media_type;
        """
    )
