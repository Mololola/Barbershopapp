"""worker leave job: business_name on workers, worker update policy

Revision ID: c305ecd7de27
Revises: 658403671135
Create Date: 2026-07-23 23:47:26.739208

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c305ecd7de27'
down_revision: Union[str, Sequence[str], None] = '658403671135'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.

    Denormalized (same reasoning as worker_invitations.business_name — see
    658403671135): lets a worker see who they currently work for without
    needing cross-table RLS read access to `businesses`.
    """
    op.execute(
        """
        alter table workers add column business_name text;

        update workers
        set business_name = businesses.name
        from businesses
        where businesses.id = workers.business_id;

        alter table workers alter column business_name set not null;

        -- Lets a worker set their own `workers` row inactive to leave a job,
        -- freeing up the one-active-business-per-profile constraint.
        create policy "worker update own worker row"
            on workers for update
            using (auth.uid() = profile_id)
            with check (auth.uid() = profile_id);
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop policy "worker update own worker row" on workers;
        alter table workers drop column business_name;
        """
    )
