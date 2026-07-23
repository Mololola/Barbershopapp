"""add currency to businesses

Revision ID: 8e861842851e
Revises: 8cf8327de9f9
Create Date: 2026-07-23 18:06:38.422141

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '8e861842851e'
down_revision: Union[str, Sequence[str], None] = '8cf8327de9f9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        alter table businesses
            add column currency text not null default 'GBP'
            check (char_length(currency) = 3);

        alter table businesses alter column currency drop default;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("alter table businesses drop column currency;")
