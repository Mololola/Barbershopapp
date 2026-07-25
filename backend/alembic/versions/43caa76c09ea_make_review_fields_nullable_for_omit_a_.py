"""make review fields nullable for omit-a-rating flow

Revision ID: 43caa76c09ea
Revises: 5cc90dd1bc71
Create Date: 2026-07-24 18:12:02.081866

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '43caa76c09ea'
down_revision: Union[str, Sequence[str], None] = '5cc90dd1bc71'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.

    The existing `check (x between 1 and 5)` constraints already allow NULL
    (a NULL comparison is neither true nor false, so Postgres CHECK doesn't
    reject it) — only the NOT NULL constraints need dropping.
    """
    op.execute(
        """
        alter table reviews alter column shop_rating drop not null;
        alter table reviews alter column worker_rating drop not null;
        alter table reviews alter column haircut_rating drop not null;
        alter table reviews alter column haircut_type drop not null;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        alter table reviews alter column haircut_type set not null;
        alter table reviews alter column haircut_rating set not null;
        alter table reviews alter column worker_rating set not null;
        alter table reviews alter column shop_rating set not null;
        """
    )
