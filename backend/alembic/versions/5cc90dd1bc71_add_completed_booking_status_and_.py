"""add completed booking status and reviews table

Revision ID: 5cc90dd1bc71
Revises: 325e1c99e67f
Create Date: 2026-07-24 17:23:23.876138

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5cc90dd1bc71'
down_revision: Union[str, Sequence[str], None] = '325e1c99e67f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        alter table bookings drop constraint bookings_status_check;
        alter table bookings add constraint bookings_status_check
            check (status in ('confirmed', 'cancelled', 'completed'));
        alter table bookings add column completed_at timestamptz;

        create table reviews (
            id uuid primary key default gen_random_uuid(),
            booking_id uuid not null unique references bookings(id) on delete cascade,
            business_id uuid not null references businesses(id) on delete cascade,
            worker_id uuid not null references workers(id) on delete cascade,
            customer_id uuid not null references profiles(id) on delete cascade,
            shop_rating smallint not null check (shop_rating between 1 and 5),
            shop_comment text,
            worker_rating smallint not null check (worker_rating between 1 and 5),
            worker_comment text,
            haircut_rating smallint not null check (haircut_rating between 1 and 5),
            haircut_comment text,
            haircut_type text not null,
            created_at timestamptz not null default now()
        );

        alter table reviews enable row level security;

        -- Public-facing feedback, same reasoning as services/opening_hours —
        -- nothing private in a review.
        create policy "authenticated read reviews"
            on reviews for select
            using (auth.uid() is not null);

        -- The unique constraint on booking_id is the real "one review per
        -- booking" guarantee; this check just keeps reviews tied to a
        -- booking that's actually done and belongs to the reviewer.
        create policy "customer insert own completed booking review"
            on reviews for insert
            with check (
                auth.uid() = customer_id
                and exists (
                    select 1 from bookings
                    where bookings.id = reviews.booking_id
                    and bookings.customer_id = auth.uid()
                    and bookings.status = 'completed'
                )
            );
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop table reviews;
        alter table bookings drop column completed_at;
        alter table bookings drop constraint bookings_status_check;
        alter table bookings add constraint bookings_status_check
            check (status in ('confirmed', 'cancelled'));
        """
    )
