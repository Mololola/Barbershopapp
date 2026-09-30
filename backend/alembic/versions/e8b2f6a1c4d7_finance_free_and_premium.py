"""finance tool: price snapshots, dated costs, other income, premium subscription

Revision ID: e8b2f6a1c4d7
Revises: d4a7e2c9f1b3
Create Date: 2026-10-01 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e8b2f6a1c4d7'
down_revision: Union[str, Sequence[str], None] = 'd4a7e2c9f1b3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- What the customer was charged, frozen at booking time. Revenue used
        -- the service's *current* price, so raising a price silently
        -- rewrote every past month's figures. Existing bookings take their
        -- service's price now — the best record there is.
        alter table bookings add column price_cents integer;
        update bookings b set price_cents = s.price_cents from services s where s.id = b.service_id;
        alter table bookings alter column price_cents set not null,
            add constraint bookings_price_cents_check check (price_cents >= 0);

        -- Costs become dated so every past month's profit stays true: a
        -- 'monthly' cost applies from starts_on until ends_on (inclusive,
        -- open-ended if null); a 'one_off' cost applies to starts_on's month
        -- only. Months are stored as their first day.
        alter table business_cost_items
            add column kind text not null default 'monthly' check (kind in ('monthly', 'one_off')),
            add column starts_on date not null default date_trunc('month', now())::date,
            add column ends_on date,
            add constraint business_cost_items_month_starts check (
                extract(day from starts_on) = 1 and (ends_on is null or extract(day from ends_on) = 1)
            ),
            add constraint business_cost_items_one_off_no_end check (kind = 'monthly' or ends_on is null),
            add constraint business_cost_items_ends_after_start check (ends_on is null or ends_on >= starts_on),
            add constraint business_cost_items_amount_check check (amount_cents >= 0);

        -- Stopping a monthly cost (or changing its amount from a given
        -- month) sets ends_on, so owners now update rows, not just add them.
        create policy "owner update cost items"
            on business_cost_items for update
            using (business_id in (select id from businesses where owner_id = auth.uid()))
            with check (business_id in (select id from businesses where owner_id = auth.uid()));

        -- Walk-ins and cash: without them a shop that takes many looks
        -- unprofitable and every figure the tool shows is wrong.
        create table business_other_income (
            id uuid primary key default gen_random_uuid(),
            business_id uuid not null references businesses(id) on delete cascade,
            month date not null check (extract(day from month) = 1),
            amount_cents integer not null check (amount_cents >= 0),
            note text,
            created_at timestamptz not null default now(),
            unique (business_id, month)
        );
        alter table business_other_income enable row level security;
        create policy "owner manage other income"
            on business_other_income for all
            using (business_id in (select id from businesses where owner_id = auth.uid()))
            with check (business_id in (select id from businesses where owner_id = auth.uid()));

        -- Premium becomes a monthly subscription (was a one-off unlock;
        -- anyone who paid that keeps premium via paid_at). Written only by
        -- the backend's Stripe webhook handler.
        alter table business_finance_access
            add column stripe_subscription_id text unique,
            add column subscription_status text
                check (subscription_status in ('active', 'past_due', 'canceled'));
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        alter table business_finance_access drop column stripe_subscription_id, drop column subscription_status;
        drop table business_other_income;
        drop policy "owner update cost items" on business_cost_items;
        alter table business_cost_items
            drop constraint business_cost_items_amount_check,
            drop constraint business_cost_items_ends_after_start,
            drop constraint business_cost_items_one_off_no_end,
            drop constraint business_cost_items_month_starts,
            drop column ends_on, drop column starts_on, drop column kind;
        alter table bookings drop constraint bookings_price_cents_check, drop column price_cents;
        """
    )
