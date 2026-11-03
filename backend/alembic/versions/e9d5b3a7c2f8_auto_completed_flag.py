"""remember which bookings were completed automatically

Revision ID: e9d5b3a7c2f8
Revises: e8c4a2f6d3b7
Create Date: 2026-11-03 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'e9d5b3a7c2f8'
down_revision: Union[str, Sequence[str], None] = 'e8c4a2f6d3b7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.

    A booking nobody marked is completed by auto_complete_bookings and so
    counts as income in Finance. The shop is asked to check these, and can
    turn one into a no-show for 7 days (see mark_no_show in bookings.py).
    """
    op.execute(
        """
        alter table bookings add column auto_completed boolean not null default false;

        create or replace function auto_complete_bookings() returns void
        language sql security definer set search_path = public, pg_temp as $$
            update bookings set status = 'completed', completed_at = now(), auto_completed = true
            where status = 'confirmed' and end_time <= now() - interval '2 hours';
        $$;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        create or replace function auto_complete_bookings() returns void
        language sql security definer set search_path = public, pg_temp as $$
            update bookings set status = 'completed', completed_at = now()
            where status = 'confirmed' and end_time <= now() - interval '2 hours';
        $$;

        alter table bookings drop column auto_completed;
        """
    )
