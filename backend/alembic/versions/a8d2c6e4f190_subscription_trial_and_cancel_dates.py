"""subscription trial end and scheduled cancellation, for the in-app cancel

Revision ID: a8d2c6e4f190
Revises: f1c9a7d3e5b2
Create Date: 2026-10-01 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a8d2c6e4f190'
down_revision: Union[str, Sequence[str], None] = 'f1c9a7d3e5b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Copied from the Stripe subscription (customer.subscription.*
        -- webhooks) so the app can say "free until X" and "canceled — you
        -- keep access until X" without a Stripe round-trip.
        alter table business_subscriptions
            add column trial_ends_at timestamptz,
            add column cancel_at timestamptz;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("alter table business_subscriptions drop column trial_ends_at, drop column cancel_at;")
