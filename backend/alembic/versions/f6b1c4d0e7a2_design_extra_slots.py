"""design extra slots (paid 3D-designer bundle)

Revision ID: f6b1c4d0e7a2
Revises: a2c7e1f4b930
Create Date: 2026-07-29 16:20:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f6b1c4d0e7a2'
down_revision: Union[str, Sequence[str], None] = 'a2c7e1f4b930'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        create table design_extra_slots (
            id uuid primary key default gen_random_uuid(),
            profile_id uuid not null unique references profiles(id) on delete cascade,
            extra_slots integer not null default 0,
            created_at timestamptz not null default now(),
            updated_at timestamptz not null default now()
        );

        alter table design_extra_slots enable row level security;

        create policy "owner select own extra slots"
            on design_extra_slots for select
            using (auth.uid() = profile_id);
        -- No insert/update/delete policy — only FastAPI (service-role)
        -- ever writes this table, same reasoning as business_subscriptions
        -- and business_finance_access: every write is a Stripe webhook.

        -- Design creation is a direct client -> Supabase insert (no FastAPI
        -- endpoint sits in front of it, unlike bookings), so the free-tier
        -- cap can no longer be a client-side-only check now that paying to
        -- raise it is real money — same "never rely on app-level
        -- check-then-insert alone" principle as the booking EXCLUDE
        -- constraint (see docs/architecture.md). The literal 3 here must
        -- stay in sync with maxFreeDesigns in
        -- mobile/lib/features/designer/application/designer_controller.dart.
        create or replace function enforce_design_slot_cap() returns trigger as $$
        declare
          current_count integer;
          extra integer;
        begin
          select count(*) into current_count from haircut_designs where owner_id = new.owner_id;
          select coalesce(extra_slots, 0) into extra from design_extra_slots where profile_id = new.owner_id;
          if current_count >= (3 + coalesce(extra, 0)) then
            raise exception 'Design slot cap reached' using errcode = 'P0001';
          end if;
          return new;
        end;
        $$ language plpgsql;

        create trigger design_slot_cap_trigger
            before insert on haircut_designs
            for each row execute function enforce_design_slot_cap();
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop trigger design_slot_cap_trigger on haircut_designs;
        drop function enforce_design_slot_cap();
        drop table design_extra_slots;
        """
    )
