"""basic cut prices the subscription; services are removed, never deleted

Revision ID: c5e8a1d4f7b2
Revises: b3d9f2c7a1e4
Create Date: 2026-10-15 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c5e8a1d4f7b2'
down_revision: Union[str, Sequence[str], None] = 'b3d9f2c7a1e4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- The shop's standard haircut: the subscription is 10x its price
        -- (app/api/billing.py). At most one per business.
        alter table services add column is_basic_cut boolean not null default false;
        update services s set is_basic_cut = true
            from (select distinct on (business_id) id from services
                  where is_active order by business_id, created_at) first_service
            where s.id = first_service.id;
        create unique index services_one_basic_cut on services (business_id) where is_basic_cut;

        -- A shop's first service (or first after it had none) is its basic
        -- cut, so setup never leaves a shop without one.
        create function services_default_basic_cut() returns trigger language plpgsql as $$
        begin
            if not exists (select 1 from services where business_id = new.business_id and is_basic_cut) then
                new.is_basic_cut := true;
            end if;
            return new;
        end $$;
        create trigger services_default_basic_cut before insert on services
            for each row execute function services_default_basic_cut();

        -- A removed service can't stay the basic cut.
        create function services_clear_removed_basic_cut() returns trigger language plpgsql as $$
        begin
            if not new.is_active then
                new.is_basic_cut := false;
            end if;
            return new;
        end $$;
        create trigger services_clear_removed_basic_cut before update on services
            for each row execute function services_clear_removed_basic_cut();

        -- Deleting a service cascaded to every booking that used it (and
        -- their reviews and earned rewards). Services are now removed by
        -- setting is_active = false; only deleting the whole business
        -- deletes them.
        drop policy "owner delete services" on services;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        create policy "owner delete services"
            on services for delete
            using (business_id in (select id from businesses where owner_id = auth.uid()));
        drop trigger services_clear_removed_basic_cut on services;
        drop function services_clear_removed_basic_cut();
        drop trigger services_default_basic_cut on services;
        drop function services_default_basic_cut();
        drop index services_one_basic_cut;
        alter table services drop column is_basic_cut;
        """
    )
