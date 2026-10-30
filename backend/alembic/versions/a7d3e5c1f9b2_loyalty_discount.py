"""loyalty discount: paid months per subscription, Finance Premium price

Revision ID: a7d3e5c1f9b2
Revises: f4b7c2e9a1d6
Create Date: 2026-10-29 18:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'a7d3e5c1f9b2'
down_revision: Union[str, Sequence[str], None] = 'f4b7c2e9a1d6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- One row per regular monthly invoice paid, keyed by the invoice so a
        -- webhook delivered twice can't count a month twice. Counted per
        -- subscription: the loyalty discount (see app/api/billing.py)
        -- starts again with a new one. Only FastAPI reads or writes it.
        create table subscription_paid_invoices (
            stripe_invoice_id text primary key,
            stripe_subscription_id text not null,
            created_at timestamptz not null default now()
        );
        create index subscription_paid_invoices_subscription_idx
            on subscription_paid_invoices (stripe_subscription_id);
        alter table subscription_paid_invoices enable row level security;

        -- amount_cents was the old one-off price, unused since Finance
        -- Premium became a subscription; it now holds the monthly price,
        -- which the loyalty discount lowers.
        alter table business_finance_access rename column amount_cents to monthly_amount_cents;
        alter table business_finance_access alter column monthly_amount_cents set default 999;
        update business_finance_access set monthly_amount_cents = 999;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        alter table business_finance_access alter column monthly_amount_cents set default 4500;
        alter table business_finance_access rename column monthly_amount_cents to amount_cents;
        drop table subscription_paid_invoices;
        """
    )
