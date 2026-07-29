"""business subscriptions and auto-suspend

Revision ID: 5ff57731d816
Revises: 766be8cb9b71
Create Date: 2026-07-29 14:50:03.992425

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5ff57731d816'
down_revision: Union[str, Sequence[str], None] = '766be8cb9b71'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        create table business_subscriptions (
            id uuid primary key default gen_random_uuid(),
            business_id uuid not null unique references businesses(id) on delete cascade,
            stripe_customer_id text,
            stripe_subscription_id text unique,
            monthly_amount_cents integer not null,
            status text not null default 'incomplete'
                check (status in ('incomplete', 'active', 'past_due', 'suspended', 'canceled')),
            grandfathered boolean not null default false,
            suspended_at timestamptz,
            current_period_end timestamptz,
            created_at timestamptz not null default now(),
            updated_at timestamptz not null default now()
        );

        alter table business_subscriptions enable row level security;

        create policy "owner select own subscription"
            on business_subscriptions for select
            using (business_id in (select id from businesses where owner_id = auth.uid()));
        -- No insert/update/delete policy — only FastAPI (service-role)
        -- ever writes this table; every write is either a Stripe webhook
        -- or a checkout-session creation, both money-adjacent.

        alter table businesses add column is_suspended boolean not null default false;

        -- Webhook idempotency — Stripe retries on non-2xx and can
        -- redeliver; every webhook handler checks this before acting.
        create table stripe_events (
            id text primary key,
            type text not null,
            processed_at timestamptz not null default now()
        );
        alter table stripe_events enable row level security;
        -- No policies at all — never read or written by any client, only
        -- FastAPI via its service-role connection.

        -- Grandfather every pre-billing business in as active, no charge,
        -- so existing test data keeps working under the new requirement.
        insert into business_subscriptions (business_id, monthly_amount_cents, status, grandfathered)
            select id, 0, 'active', true from businesses;

        create or replace view businesses_public as
            select id, owner_id, name, currency, created_at, logo_url
            from businesses
            where is_suspended = false;

        revoke all on businesses_public from public, anon, authenticated;
        grant select on businesses_public to authenticated;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        create or replace view businesses_public as
            select id, owner_id, name, currency, created_at, logo_url from businesses;

        revoke all on businesses_public from public, anon, authenticated;
        grant select on businesses_public to authenticated;

        drop table stripe_events;
        alter table businesses drop column is_suspended;
        drop table business_subscriptions;
        """
    )
