"""restrict avatars and haircut-thumbnails buckets to images with a size cap

Revision ID: f4b7c2e9a1d6
Revises: e9a4c2f7b8d1
Create Date: 2026-10-29 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'f4b7c2e9a1d6'
down_revision: Union[str, Sequence[str], None] = 'e9a4c2f7b8d1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- As post-media got in c8a1f5d47b6e: both public buckets took any
        -- file of any size into the uploader's own folder (an HTML page or
        -- a gigabyte served from our storage). avatars holds profile
        -- photos, shop logos and covers, picked at 1600 px at most; a
        -- design thumbnail is a full-screen PNG of the 3D view.
        update storage.buckets
        set file_size_limit = 5242880, -- 5 MiB
            allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
        where id = 'avatars';

        update storage.buckets
        set file_size_limit = 10485760, -- 10 MiB
            allowed_mime_types = array['image/png']
        where id = 'haircut-thumbnails';
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        update storage.buckets
        set file_size_limit = null,
            allowed_mime_types = null
        where id in ('avatars', 'haircut-thumbnails');
        """
    )
