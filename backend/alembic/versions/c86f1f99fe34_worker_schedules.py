"""worker schedules

Revision ID: c86f1f99fe34
Revises: 1409471fb0ca
Create Date: 2026-07-27 18:40:28.323610

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c86f1f99fe34'
down_revision: Union[str, Sequence[str], None] = '1409471fb0ca'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        create table worker_schedules (
            id uuid primary key default gen_random_uuid(),
            worker_id uuid not null references workers(id) on delete cascade,
            day_of_week smallint not null check (day_of_week between 0 and 6),
            is_closed boolean not null default true,
            open_time time,
            close_time time,
            unique (worker_id, day_of_week)
        );

        alter table worker_schedules enable row level security;

        -- Single "for all" policy covers select/insert/update/delete — only
        -- the owning business manages this table, no other reader exists.
        create policy "owner manage worker_schedules"
            on worker_schedules for all
            using (
                exists (
                    select 1 from workers
                    join businesses on businesses.id = workers.business_id
                    where workers.id = worker_schedules.worker_id
                    and businesses.owner_id = auth.uid()
                )
            )
            with check (
                exists (
                    select 1 from workers
                    join businesses on businesses.id = workers.business_id
                    where workers.id = worker_schedules.worker_id
                    and businesses.owner_id = auth.uid()
                )
            );
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("drop table worker_schedules;")
