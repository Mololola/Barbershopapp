"""conversations and messages

Revision ID: c3d4fbf26e85
Revises: 10753445f58e
Create Date: 2026-07-28 19:27:08.649575

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c3d4fbf26e85'
down_revision: Union[str, Sequence[str], None] = '10753445f58e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- Canonical ordering (participant_a_id < participant_b_id) plus the
        -- unique constraint gives one row per pair regardless of who starts
        -- the conversation — the client sorts the two ids before insert.
        create table conversations (
            id uuid primary key default gen_random_uuid(),
            participant_a_id uuid not null references profiles(id) on delete cascade,
            participant_b_id uuid not null references profiles(id) on delete cascade,
            created_at timestamptz not null default now(),
            check (participant_a_id < participant_b_id),
            unique (participant_a_id, participant_b_id)
        );

        create table messages (
            id uuid primary key default gen_random_uuid(),
            conversation_id uuid not null references conversations(id) on delete cascade,
            sender_id uuid not null references profiles(id) on delete cascade,
            body text not null check (char_length(trim(body)) > 0 and char_length(body) <= 2000),
            created_at timestamptz not null default now(),
            read_at timestamptz
        );

        alter table conversations enable row level security;
        alter table messages enable row level security;

        create policy "participant select own conversations"
            on conversations for select
            using (auth.uid() = participant_a_id or auth.uid() = participant_b_id);

        create policy "participant insert own conversations"
            on conversations for insert
            with check (auth.uid() = participant_a_id or auth.uid() = participant_b_id);

        -- Needed for startOrGetConversation's upsert: PostgREST's
        -- merge-duplicates resolution compiles to INSERT ... ON CONFLICT DO
        -- UPDATE, which requires UPDATE permission on the conflicting row
        -- even though the "update" just re-sets the same values.
        create policy "participant update own conversations"
            on conversations for update
            using (auth.uid() = participant_a_id or auth.uid() = participant_b_id)
            with check (auth.uid() = participant_a_id or auth.uid() = participant_b_id);

        create policy "participant select own messages"
            on messages for select
            using (exists (
                select 1 from conversations c
                where c.id = messages.conversation_id
                and (auth.uid() = c.participant_a_id or auth.uid() = c.participant_b_id)
            ));

        create policy "participant insert own messages"
            on messages for insert
            with check (
                sender_id = auth.uid()
                and exists (
                    select 1 from conversations c
                    where c.id = messages.conversation_id
                    and (auth.uid() = c.participant_a_id or auth.uid() = c.participant_b_id)
                )
            );

        -- Broad on purpose (any participant, any column) rather than
        -- column-restricted — the UI only ever touches read_at, and a
        -- trigger to enforce that isn't worth it for a two-party table.
        create policy "participant mark messages read"
            on messages for update
            using (exists (
                select 1 from conversations c
                where c.id = messages.conversation_id
                and (auth.uid() = c.participant_a_id or auth.uid() = c.participant_b_id)
            ));

        -- Realtime only delivers postgres_changes events for tables added
        -- to this publication — nothing else in the app uses Realtime yet,
        -- so no other table is a member of it.
        alter publication supabase_realtime add table messages;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        alter publication supabase_realtime drop table messages;
        drop table messages;
        drop table conversations;
        """
    )
