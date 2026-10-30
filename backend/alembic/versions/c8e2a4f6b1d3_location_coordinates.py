"""location coordinates, for sorting shops by distance

Revision ID: c8e2a4f6b1d3
Revises: a7d3e5c1f9b2
Create Date: 2026-10-30 09:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'c8e2a4f6b1d3'
down_revision: Union[str, Sequence[str], None] = 'a7d3e5c1f9b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Filled in by the backend from the postcode (app/services/geocoding.py),
        -- never by the app. Null until then, or when the postcode isn't found;
        -- such a shop still lists, just without a distance. The app replaces
        -- a shop's locations on every save, so new rows start null again.
        alter table locations
            add column latitude double precision,
            add column longitude double precision;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("alter table locations drop column latitude, drop column longitude;")
