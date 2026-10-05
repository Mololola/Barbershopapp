"""Finance Premium scheduled cancellation, for the in-app cancel

Revision ID: c3a9d5e7f1b4
Revises: b5e1f3a7c9d2
Create Date: 2026-10-05 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c3a9d5e7f1b4'
down_revision: Union[str, Sequence[str], None] = 'b5e1f3a7c9d2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Same as business_subscriptions.cancel_at (a8d2c6e4f190): when a
        -- cancelled Finance Premium stops, so the app can say so.
        alter table business_finance_access add column cancel_at timestamptz;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        alter table business_finance_access drop column cancel_at;
        """
    )
