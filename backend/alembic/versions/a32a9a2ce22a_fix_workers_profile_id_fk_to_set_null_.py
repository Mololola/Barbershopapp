"""fix workers profile_id fk to set null on profile delete

Revision ID: a32a9a2ce22a
Revises: 9e2acc1d32c3
Create Date: 2026-09-22 23:58:07.460104

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a32a9a2ce22a'
down_revision: Union[str, Sequence[str], None] = '9e2acc1d32c3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        alter table workers drop constraint workers_profile_id_fkey;
        alter table workers
            add constraint workers_profile_id_fkey
            foreign key (profile_id) references profiles(id) on delete set null;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        alter table workers drop constraint workers_profile_id_fkey;
        alter table workers
            add constraint workers_profile_id_fkey
            foreign key (profile_id) references profiles(id);
        """
    )
