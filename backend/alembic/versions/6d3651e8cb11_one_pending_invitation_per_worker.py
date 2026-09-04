"""one pending invitation per business+worker at a time

Revision ID: 6d3651e8cb11
Revises: d4911496e1da
Create Date: 2026-08-19 02:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '6d3651e8cb11'
down_revision: Union[str, Sequence[str], None] = 'd4911496e1da'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.

    Nothing stopped a business from sending the same worker a second (third,
    fourth...) invitation while an earlier one was still pending — enforced
    at the database, same philosophy as workers_one_active_business_per_
    profile (ba453d5e53aa), not left to the client disabling a button.
    """
    op.execute(
        """
        create unique index worker_invitations_one_pending_per_business_worker
            on worker_invitations (business_id, worker_profile_id)
            where status = 'pending';
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop index worker_invitations_one_pending_per_business_worker;
        """
    )
