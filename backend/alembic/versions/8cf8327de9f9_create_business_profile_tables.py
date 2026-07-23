"""create business profile tables

Revision ID: 8cf8327de9f9
Revises: 41822f3051ec
Create Date: 2026-07-23 17:17:35.621144

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '8cf8327de9f9'
down_revision: Union[str, Sequence[str], None] = '41822f3051ec'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        create extension if not exists pgcrypto;

        create table businesses (
            id uuid primary key default gen_random_uuid(),
            owner_id uuid not null unique references profiles(id) on delete cascade,
            name text not null,
            phone text,
            created_at timestamptz not null default now()
        );

        alter table businesses enable row level security;

        create policy "owner select business"
            on businesses for select
            using (auth.uid() = owner_id);

        create policy "owner insert business"
            on businesses for insert
            with check (auth.uid() = owner_id);

        create policy "owner update business"
            on businesses for update
            using (auth.uid() = owner_id);

        create table locations (
            id uuid primary key default gen_random_uuid(),
            business_id uuid not null references businesses(id) on delete cascade,
            address_line text not null,
            city text not null,
            created_at timestamptz not null default now()
        );

        create table opening_hours (
            id uuid primary key default gen_random_uuid(),
            business_id uuid not null references businesses(id) on delete cascade,
            day_of_week smallint not null check (day_of_week between 0 and 6),
            is_closed boolean not null default false,
            open_time time,
            close_time time,
            unique (business_id, day_of_week)
        );

        create table services (
            id uuid primary key default gen_random_uuid(),
            business_id uuid not null references businesses(id) on delete cascade,
            name text not null,
            price_cents integer not null check (price_cents >= 0),
            duration_minutes integer not null check (duration_minutes > 0),
            is_active boolean not null default true,
            created_at timestamptz not null default now()
        );

        create table workers (
            id uuid primary key default gen_random_uuid(),
            business_id uuid not null references businesses(id) on delete cascade,
            name text not null,
            is_active boolean not null default true,
            created_at timestamptz not null default now()
        );

        alter table locations enable row level security;
        alter table opening_hours enable row level security;
        alter table services enable row level security;
        alter table workers enable row level security;
        """
    )

    for table in ("locations", "opening_hours", "services", "workers"):
        op.execute(
            f"""
            create policy "owner select {table}"
                on {table} for select
                using (business_id in (select id from businesses where owner_id = auth.uid()));

            create policy "owner insert {table}"
                on {table} for insert
                with check (business_id in (select id from businesses where owner_id = auth.uid()));

            create policy "owner update {table}"
                on {table} for update
                using (business_id in (select id from businesses where owner_id = auth.uid()));

            create policy "owner delete {table}"
                on {table} for delete
                using (business_id in (select id from businesses where owner_id = auth.uid()));
            """
        )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop table workers;
        drop table services;
        drop table opening_hours;
        drop table locations;
        drop table businesses;
        """
    )
