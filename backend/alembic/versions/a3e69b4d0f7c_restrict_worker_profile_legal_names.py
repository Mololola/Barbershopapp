"""restrict broad worker_profiles read back to is_looking_for_work only

Revision ID: a3e69b4d0f7c
Revises: d7f3a92c1e58
Create Date: 2026-08-07 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a3e69b4d0f7c'
down_revision: Union[str, Sequence[str], None] = 'd7f3a92c1e58'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- worker_profiles carries legal_first_name/legal_last_name/
        -- legal_second_last_name — real legal identity, not a username.
        -- The original policy (367025cd9127's predecessor, later dropped
        -- in 0cb7a34078cb) correctly scoped broad read access to
        -- is_looking_for_work = true. 0cb7a34078cb replaced it with an
        -- unconditional auth.uid() is not null, justified in its own
        -- comment by "findWorkersByName already filters
        -- is_looking_for_work = true itself, so search results are
        -- unaffected" — true for the app's own UI, but RLS is the actual
        -- security boundary, not a client-side .eq() filter: anyone with
        -- a valid session can query worker_profiles directly via
        -- PostgREST and bypass that filter entirely, seeing every
        -- worker's legal name regardless of whether they ever opted into
        -- being discoverable. Restores the narrower condition.
        --
        -- Not a regression for either current consumer: findWorkersByName
        -- and fetchWorkersLookingForWork (business_repository.dart) both
        -- already only want is_looking_for_work = true rows. A worker's
        -- own profile stays visible to them via "owner select worker
        -- profile" regardless of the flag, and an inviting business keeps
        -- seeing an invited worker via "business can read invited worker
        -- profiles" regardless of the flag — neither depends on this
        -- policy.
        drop policy "authenticated read worker profiles" on worker_profiles;

        create policy "public read looking-for-work worker profiles"
            on worker_profiles for select
            using (is_looking_for_work = true);
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop policy "public read looking-for-work worker profiles" on worker_profiles;

        create policy "authenticated read worker profiles"
            on worker_profiles for select
            using (auth.uid() is not null);
        """
    )
