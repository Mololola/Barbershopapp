"""let customers call business_is_listed, which businesses_public filters on

Revision ID: b5e1f3a7c9d2
Revises: a8d2c6e4f190
Create Date: 2026-10-05 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b5e1f3a7c9d2'
down_revision: Union[str, Sequence[str], None] = 'a8d2c6e4f190'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- A view runs with its owner's table rights, but EXECUTE on the
        -- functions it calls is checked against the querying user, so
        -- f1c9a7d3e5b2's revoke broke customer browsing. Only a yes/no per
        -- shop leaks; business_hidden_since (the dates) stays revoked.
        grant execute on function public.business_is_listed(uuid) to authenticated;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        revoke execute on function public.business_is_listed(uuid) from authenticated;
        """
    )
