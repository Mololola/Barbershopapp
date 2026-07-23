"""fix RLS recursion: denormalize business name onto invitations

Revision ID: 658403671135
Revises: 415cc0976530
Create Date: 2026-07-23 19:12:29.147784

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '658403671135'
down_revision: Union[str, Sequence[str], None] = '415cc0976530'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.

    The "invited worker can read business name" policy on `businesses` (added
    in 415cc0976530) queries `worker_invitations`, whose own SELECT policy
    queries `businesses` right back — Postgres detects the mutual RLS
    dependency and raises "infinite recursion detected in policy for relation
    businesses" on ANY read of `businesses`, not just the invitation path.
    Fix: drop that policy and denormalize the business name onto the
    invitation row at creation time instead, so the worker never needs
    cross-table RLS access to `businesses` at all.
    """
    op.execute(
        """
        drop policy "invited worker can read business name" on businesses;

        alter table worker_invitations add column business_name text;

        update worker_invitations
        set business_name = businesses.name
        from businesses
        where businesses.id = worker_invitations.business_id;

        alter table worker_invitations alter column business_name set not null;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        alter table worker_invitations drop column business_name;

        create policy "invited worker can read business name"
            on businesses for select
            using (
                id in (
                    select business_id from worker_invitations
                    where worker_invitations.worker_profile_id = auth.uid()
                )
            );
        """
    )
