"""lock down profile privilege columns

Revision ID: e91a5c3f7d24
Revises: d3f8a91c2b4e
Create Date: 2026-08-06 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e91a5c3f7d24'
down_revision: Union[str, Sequence[str], None] = 'd3f8a91c2b4e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- "update own profile" (367025cd9127) has a USING clause but no
        -- WITH CHECK and no column restriction — Postgres RLS UPDATE
        -- policies gate which ROWS are touchable, not which COLUMNS, so
        -- "you may update your own row" silently means "you may update
        -- any column on your own row." is_admin/is_quality_reviewer/role
        -- were added later (75f1a74951ff) onto that same unrestricted
        -- policy, letting any authenticated user PATCH their own
        -- is_admin=true via a raw PostgREST call, bypassing the app
        -- entirely. Two independent layers, either alone would close
        -- this, both is defense in depth:

        -- 1. Column-level grant: Postgres checks this BEFORE any RLS
        -- policy is even evaluated, so this alone fully closes the hole
        -- regardless of policy logic.
        revoke update (is_admin, is_quality_reviewer, role) on profiles from authenticated;

        -- 2. WITH CHECK belt-and-suspenders: explicitly reject any UPDATE
        -- that changes these three columns from their currently-stored
        -- value. Bare column references in WITH CHECK evaluate against
        -- the proposed NEW row; the subquery reads the pre-statement
        -- (OLD) value of the same row via its own snapshot — standard
        -- Postgres/Supabase idiom for "this column may not change" since
        -- WITH CHECK has no direct OLD/NEW syntax the way a trigger does.
        drop policy "update own profile" on profiles;

        create policy "update own profile"
            on profiles for update
            using (auth.uid() = id)
            with check (
                auth.uid() = id
                and is_admin = (select p.is_admin from profiles p where p.id = auth.uid())
                and is_quality_reviewer = (select p.is_quality_reviewer from profiles p where p.id = auth.uid())
                and role = (select p.role from profiles p where p.id = auth.uid())
            );
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop policy "update own profile" on profiles;

        create policy "update own profile"
            on profiles for update
            using (auth.uid() = id);

        grant update (is_admin, is_quality_reviewer, role) on profiles to authenticated;
        """
    )
