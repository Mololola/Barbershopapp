"""public read for locations (missed in bookings migration)

Revision ID: 325e1c99e67f
Revises: 376aa11dda81
Create Date: 2026-07-24 00:33:01.410376

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '325e1c99e67f'
down_revision: Union[str, Sequence[str], None] = '376aa11dda81'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        create policy "authenticated read locations"
            on locations for select
            using (auth.uid() is not null);
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute('drop policy "authenticated read locations" on locations;')
