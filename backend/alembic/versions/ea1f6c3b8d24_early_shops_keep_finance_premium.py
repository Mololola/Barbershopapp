"""shops signing up within a year of launch keep Finance Premium free

Revision ID: ea1f6c3b8d24
Revises: e9d5b3a7c2f8
Create Date: 2026-11-03 13:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'ea1f6c3b8d24'
down_revision: Union[str, Sequence[str], None] = 'e9d5b3a7c2f8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.

    The flag is stored once, at signup, on business_finance_access (which
    finance_premium_state already reads), and goes when the business is
    deleted. stores_launched_at() is null until both stores are live, so
    test shops made before launch can still try the paid flow; at launch a
    migration replaces it with the publish date. The shop subscription
    itself is not affected.
    """
    op.execute(
        """
        create function stores_launched_at() returns timestamptz
        language sql stable as $$ select null::timestamptz $$;

        create function businesses_grandfather_finance_premium() returns trigger
        language plpgsql security definer set search_path = public, pg_temp as $$
        declare
            launched_at timestamptz := stores_launched_at();
        begin
            if launched_at is not null and now() < launched_at + interval '1 year' then
                insert into business_finance_access (business_id, grandfathered) values (new.id, true)
                on conflict (business_id) do update set grandfathered = true;
            end if;
            return new;
        end;
        $$;
        revoke all on function businesses_grandfather_finance_premium() from public, anon, authenticated;

        create trigger businesses_grandfather_finance_premium
            after insert on businesses
            for each row execute function businesses_grandfather_finance_premium();
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop trigger businesses_grandfather_finance_premium on businesses;
        drop function businesses_grandfather_finance_premium();
        drop function stores_launched_at();
        """
    )
