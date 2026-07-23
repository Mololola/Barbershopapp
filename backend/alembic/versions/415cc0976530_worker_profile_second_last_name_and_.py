"""worker profile second last name and cross-visibility RLS for invitations

Revision ID: 415cc0976530
Revises: 3dc957c98849
Create Date: 2026-07-23 18:55:07.170123

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '415cc0976530'
down_revision: Union[str, Sequence[str], None] = '3dc957c98849'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        alter table worker_profiles add column legal_second_last_name text;

        -- An invited worker couldn't previously see the inviting business's
        -- name (RLS on `businesses` was owner-only), so the embedded
        -- `businesses(name)` in their invitations list came back null.
        create policy "invited worker can read business name"
            on businesses for select
            using (
                id in (
                    select business_id from worker_invitations
                    where worker_invitations.worker_profile_id = auth.uid()
                )
            );

        -- Symmetrically, a business should be able to read the worker_profiles
        -- row (for the real name) of anyone they've invited, even after that
        -- worker is no longer publicly "looking for work" (e.g. once hired).
        create policy "business can read invited worker profiles"
            on worker_profiles for select
            using (
                profile_id in (
                    select worker_profile_id from worker_invitations
                    where worker_invitations.business_id in (
                        select id from businesses where owner_id = auth.uid()
                    )
                )
            );
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop policy "business can read invited worker profiles" on worker_profiles;
        drop policy "invited worker can read business name" on businesses;
        alter table worker_profiles drop column legal_second_last_name;
        """
    )
