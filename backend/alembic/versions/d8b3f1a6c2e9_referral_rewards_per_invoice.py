"""referral rewards, one per paid subscription invoice

Revision ID: d8b3f1a6c2e9
Revises: c3a9d5e7f1b4
Create Date: 2026-10-07 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd8b3f1a6c2e9'
down_revision: Union[str, Sequence[str], None] = 'c3a9d5e7f1b4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- A referral reward is 5% of one paid shop-subscription invoice.
        -- Unique, like review_id, so a redelivered Stripe event can't credit
        -- the same invoice twice.
        alter table reward_ledger add column stripe_invoice_id text unique;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        alter table reward_ledger drop column stripe_invoice_id;
        """
    )
