"""review time always set by the database

Revision ID: e6b2d8f4a1c9
Revises: e4a9c2f7b1d6
Create Date: 2026-10-31 19:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'e6b2d8f4a1c9'
down_revision: Union[str, Sequence[str], None] = 'e4a9c2f7b1d6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.

    The review reward is only paid within 6 hours of the booking's end,
    judged by reviews.created_at. Customers insert reviews directly, so
    without this they could send an earlier created_at themselves.
    """
    op.execute(
        """
        create function reviews_stamp_created_at() returns trigger
        language plpgsql set search_path = public, pg_temp as $$
        begin
            new.created_at := now();
            return new;
        end;
        $$;

        create trigger reviews_stamp_created_at
            before insert on reviews
            for each row execute function reviews_stamp_created_at();
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop trigger reviews_stamp_created_at on reviews;
        drop function reviews_stamp_created_at();
        """
    )
