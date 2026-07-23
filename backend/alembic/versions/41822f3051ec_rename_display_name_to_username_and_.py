"""rename display_name to username and enforce uniqueness

Revision ID: 41822f3051ec
Revises: 367025cd9127
Create Date: 2026-07-23 16:26:09.626426

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '41822f3051ec'
down_revision: Union[str, Sequence[str], None] = '367025cd9127'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        alter table profiles rename column display_name to username;

        create unique index profiles_username_unique_idx on profiles (lower(username));
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop index profiles_username_unique_idx;

        alter table profiles rename column username to display_name;
        """
    )
