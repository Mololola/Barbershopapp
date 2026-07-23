"""create profiles table

Revision ID: 367025cd9127
Revises: 
Create Date: 2026-07-23 15:13:52.159821

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '367025cd9127'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        create table profiles (
            id uuid primary key references auth.users(id) on delete cascade,
            role text not null check (role in ('customer', 'business')),
            display_name text not null,
            avatar_url text,
            created_at timestamptz not null default now()
        );

        alter table profiles enable row level security;

        create policy "select own profile"
            on profiles for select
            using (auth.uid() = id);

        create policy "insert own profile"
            on profiles for insert
            with check (auth.uid() = id);

        create policy "update own profile"
            on profiles for update
            using (auth.uid() = id);
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("drop table profiles;")
