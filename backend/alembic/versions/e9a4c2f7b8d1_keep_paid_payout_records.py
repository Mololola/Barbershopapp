"""paid payouts outlive the account; a referrer can delete their account

Revision ID: e9a4c2f7b8d1
Revises: d7f2b9e4a6c1
Create Date: 2026-10-15 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e9a4c2f7b8d1'
down_revision: Union[str, Sequence[str], None] = 'd7f2b9e4a6c1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- The shop's referral blocked its referrer from deleting their
        -- account. Deleting it now ends the referral: the shop keeps paying,
        -- nobody earns the 5%.
        alter table businesses drop constraint businesses_referred_by_code_fkey;
        alter table businesses add constraint businesses_referred_by_code_fkey
            foreign key (referred_by_code) references profiles(referral_code) on delete set null;

        -- Money already paid out is a tax/accounting record: it stays when
        -- the account is deleted, with who it was paid to copied onto it.
        -- Unpaid requests are deleted with the account (app/api/account.py).
        alter table payout_requests add column requester_username text;
        update payout_requests r set requester_username = p.username from profiles p where p.id = r.profile_id;
        alter table payout_requests alter column profile_id drop not null;
        alter table payout_requests drop constraint payout_requests_profile_id_fkey;
        alter table payout_requests add constraint payout_requests_profile_id_fkey
            foreign key (profile_id) references profiles(id) on delete set null;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        delete from payout_requests where profile_id is null;
        alter table payout_requests drop constraint payout_requests_profile_id_fkey;
        alter table payout_requests add constraint payout_requests_profile_id_fkey
            foreign key (profile_id) references profiles(id) on delete cascade;
        alter table payout_requests alter column profile_id set not null;
        alter table payout_requests drop column requester_username;
        alter table businesses drop constraint businesses_referred_by_code_fkey;
        alter table businesses add constraint businesses_referred_by_code_fkey
            foreign key (referred_by_code) references profiles(referral_code);
        """
    )
