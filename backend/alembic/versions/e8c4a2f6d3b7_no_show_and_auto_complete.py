"""no-show status; bookings left unmarked complete themselves after 2 hours

Revision ID: e8c4a2f6d3b7
Revises: e6b2d8f4a1c9
Create Date: 2026-11-01 02:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'e8c4a2f6d3b7'
down_revision: Union[str, Sequence[str], None] = 'e6b2d8f4a1c9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.

    The shop gets reminders to mark a booking done (in the app); if nobody
    does within 2 hours of its end, it's marked done here so no booking is
    left open. pg_cron (Supabase's built-in scheduler) rather than the
    6-hourly GitHub job, which is too coarse for this.
    """
    op.execute(
        """
        alter table bookings drop constraint bookings_status_check;
        alter table bookings add constraint bookings_status_check
            check (status in ('confirmed', 'cancelled', 'completed', 'no_show'));

        create function auto_complete_bookings() returns void
        language sql security definer set search_path = public, pg_temp as $$
            update bookings set status = 'completed', completed_at = now()
            where status = 'confirmed' and end_time <= now() - interval '2 hours';
        $$;
        revoke all on function auto_complete_bookings() from public, anon, authenticated;

        create extension if not exists pg_cron with schema pg_catalog;
        select cron.schedule('auto-complete-bookings', '*/5 * * * *', 'select auto_complete_bookings()');
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        select cron.unschedule('auto-complete-bookings');
        drop function auto_complete_bookings();

        update bookings set status = 'cancelled' where status = 'no_show';
        alter table bookings drop constraint bookings_status_check;
        alter table bookings add constraint bookings_status_check
            check (status in ('confirmed', 'cancelled', 'completed'));
        """
    )
