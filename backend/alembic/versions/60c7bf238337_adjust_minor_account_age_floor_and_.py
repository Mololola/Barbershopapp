"""adjust minor account age floor and consent flow

Revision ID: 60c7bf238337
Revises: 832ca4a41b29
Create Date: 2026-09-14 17:45:51.923437

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '60c7bf238337'
down_revision: Union[str, Sequence[str], None] = '832ca4a41b29'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- 14 clears both countries' GDPR digital-age-of-consent thresholds
        -- (13 UK, 14 Spain) — at or above it, a minor can validly consent
        -- to their own data processing with no parent involved at all, so
        -- the verified-guardian mechanism below is no longer needed for
        -- anyone who's actually allowed to sign up.
        alter table profiles drop constraint profiles_minimum_age_check;
        alter table profiles add constraint profiles_minimum_age_check
            check (date_of_birth is null or date_of_birth <= (current_date - interval '14 years')::date);

        drop table profile_guardian_links;

        -- Recorded at signup (self-declared, not identity-verified — same
        -- as the age itself) so acceptance of the Terms/Privacy Policy is
        -- a real timestamped fact, not just an ephemeral client-side tick.
        alter table profiles add column terms_accepted_at timestamptz;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        alter table profiles drop column terms_accepted_at;

        create table profile_guardian_links (
            id uuid primary key default gen_random_uuid(),
            minor_profile_id uuid not null references profiles(id) on delete cascade,
            guardian_profile_id uuid references profiles(id) on delete cascade,
            guardian_email text not null,
            status text not null default 'pending' check (status in ('pending', 'confirmed')),
            consented_at timestamptz,
            created_at timestamptz not null default now()
        );

        alter table profile_guardian_links enable row level security;

        create unique index profile_guardian_links_one_confirmed_per_minor
            on profile_guardian_links (minor_profile_id)
            where (status = 'confirmed');

        create policy "minor select own guardian links"
            on profile_guardian_links for select
            using (auth.uid() = minor_profile_id);

        create policy "minor insert own guardian invite"
            on profile_guardian_links for insert
            with check (auth.uid() = minor_profile_id);

        create policy "invited guardian select their invite"
            on profile_guardian_links for select
            using (guardian_email = auth.email());

        create policy "invited guardian confirms"
            on profile_guardian_links for update
            using (guardian_email = auth.email() and status = 'pending')
            with check (
                guardian_profile_id = auth.uid()
                and status = 'confirmed'
                and guardian_email = (select l.guardian_email from profile_guardian_links l where l.id = profile_guardian_links.id)
                and minor_profile_id = (select l.minor_profile_id from profile_guardian_links l where l.id = profile_guardian_links.id)
                and not exists (select 1 from profiles p where p.id = auth.uid() and profile_is_minor(p))
            );

        alter table profiles drop constraint profiles_minimum_age_check;
        alter table profiles add constraint profiles_minimum_age_check
            check (date_of_birth is null or date_of_birth <= (current_date - interval '13 years')::date);
        """
    )
