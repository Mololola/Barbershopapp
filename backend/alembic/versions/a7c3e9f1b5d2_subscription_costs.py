"""the app's own subscriptions as automatic finance costs

Revision ID: a7c3e9f1b5d2
Revises: f4b8d2a6c1e7
Create Date: 2026-10-08 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a7c3e9f1b5d2'
down_revision: Union[str, Sequence[str], None] = 'f4b8d2a6c1e7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_OWNS = "business_id in (select id from businesses where owner_id = auth.uid())"


def _owner_policies(automatic_guard: str) -> str:
    return f"""
        drop policy "owner insert cost items" on business_cost_items;
        drop policy "owner update cost items" on business_cost_items;
        drop policy "owner delete cost items" on business_cost_items;
        create policy "owner insert cost items" on business_cost_items for insert
            with check ({_OWNS}{automatic_guard});
        create policy "owner update cost items" on business_cost_items for update
            using ({_OWNS}{automatic_guard}) with check ({_OWNS}{automatic_guard});
        create policy "owner delete cost items" on business_cost_items for delete
            using ({_OWNS}{automatic_guard});
    """


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Set on the cost rows the Stripe webhook keeps for what the shop
        -- pays us; owners can see them but only the backend writes them.
        alter table business_cost_items add column stripe_subscription_id text;
        """
        + _owner_policies(" and stripe_subscription_id is null")
        + """
        -- Subscriptions already being paid start counting from this month;
        -- the webhook keeps them current from here on.
        insert into business_cost_items (business_id, label, amount_cents, kind, starts_on, stripe_subscription_id)
        select business_id, 'Shop subscription', monthly_amount_cents, 'monthly',
               date_trunc('month', now())::date, stripe_subscription_id
        from business_subscriptions
        where status = 'active' and not grandfathered and stripe_subscription_id is not null
          and (trial_ends_at is null or trial_ends_at <= now());

        insert into business_cost_items (business_id, label, amount_cents, kind, starts_on, stripe_subscription_id)
        select business_id, 'Finance Premium', 999, 'monthly', date_trunc('month', now())::date, stripe_subscription_id
        from business_finance_access
        where subscription_status = 'active' and stripe_subscription_id is not null;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        "delete from business_cost_items where stripe_subscription_id is not null;"
        + _owner_policies("")
        + "alter table business_cost_items drop column stripe_subscription_id;"
    )
