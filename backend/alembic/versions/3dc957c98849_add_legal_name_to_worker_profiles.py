"""add legal name to worker profiles

Revision ID: 3dc957c98849
Revises: ba453d5e53aa
Create Date: 2026-07-23 18:41:33.568334

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '3dc957c98849'
down_revision: Union[str, Sequence[str], None] = 'ba453d5e53aa'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        alter table worker_profiles
            add column legal_first_name text not null default '',
            add column legal_last_name text not null default '';

        alter table worker_profiles alter column legal_first_name drop default;
        alter table worker_profiles alter column legal_last_name drop default;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        alter table worker_profiles
            drop column legal_first_name,
            drop column legal_last_name;
        """
    )
