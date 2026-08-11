"""restrict post-media bucket to images with a size cap

Revision ID: c8a1f5d47b6e
Revises: b4e6f28a91dc
Create Date: 2026-08-06 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c8a1f5d47b6e'
down_revision: Union[str, Sequence[str], None] = 'b4e6f28a91dc'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- post-media (6892530b9406) was created with no file_size_limit or
        -- allowed_mime_types — any authenticated user could upload an
        -- arbitrarily large file of any type into their own folder, with no
        -- rate limit on the request either (feed/posts go straight from the
        -- app to Supabase, never through FastAPI's rate limiter). The 10 MiB
        -- cap is a backstop, not the primary defense — the client now
        -- compresses images before upload (see create_post_screen.dart), so
        -- normal uploads land well under this; this just bounds what a
        -- client that skips that compression (or bypasses the app entirely)
        -- can push through.
        update storage.buckets
        set file_size_limit = 10485760, -- 10 MiB
            allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
        where id = 'post-media';
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        update storage.buckets
        set file_size_limit = null,
            allowed_mime_types = null
        where id = 'post-media';
        """
    )
