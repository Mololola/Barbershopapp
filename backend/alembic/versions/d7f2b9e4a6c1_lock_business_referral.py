"""a shop's referral is set at signup and can't be changed by its owner

Revision ID: d7f2b9e4a6c1
Revises: c5e8a1d4f7b2
Create Date: 2026-10-15 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd7f2b9e4a6c1'
down_revision: Union[str, Sequence[str], None] = 'c5e8a1d4f7b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- The referrer earns 5% of what the shop pays (app/api/billing.py),
        -- so an owner switching it later would move that money. Only app
        -- users are stopped; the backend and admin tooling run as other roles.
        create function businesses_lock_referral() returns trigger language plpgsql as $$
        begin
            if new.referred_by_code is distinct from old.referred_by_code
               and current_user in ('authenticated', 'anon') then
                raise exception 'A shop''s referral code can''t be changed';
            end if;
            return new;
        end $$;
        create trigger businesses_lock_referral before update on businesses
            for each row execute function businesses_lock_referral();
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop trigger businesses_lock_referral on businesses;
        drop function businesses_lock_referral();
        """
    )
