"""admin access requires a second-factor sign-in

Revision ID: f4b8d2a6c1e7
Revises: e2c4a8f6b1d3
Create Date: 2026-10-08 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f4b8d2a6c1e7'
down_revision: Union[str, Sequence[str], None] = 'e2c4a8f6b1d3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_ADMIN_POLICIES = [
    ("business_subscriptions", "admin select all business_subscriptions", "select"),
    ("businesses", "admin select all businesses", "select"),
    ("businesses", "admin update businesses", "update"),
    ("payout_requests", "admin select all payout requests", "select"),
    ("payout_requests", "admin update payout requests", "update"),
]


def _guard_function(admin_check: str) -> str:
    return f"""
        create or replace function public.businesses_guard_billing_columns()
        returns trigger language plpgsql set search_path to '' as $function$
        begin
            if current_user <> 'authenticated' then
                return new;
            end if;
            if new.subscription_trial_ends_at is distinct from old.subscription_trial_ends_at
               and not {admin_check} then
                raise exception 'Only an admin can change a business''s trial.' using errcode = '42501';
            end if;
            return new;
        end;
        $function$;
    """


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- An admin's session counts only once they've also entered their
        -- authenticator code (Supabase raises the token's aal to 'aal2'):
        -- admin access reaches every business and customers' bank details,
        -- so a leaked password alone mustn't open it. FastAPI's
        -- require_admin checks the same.
        create function public.is_verified_admin() returns boolean
        language sql stable set search_path to '' as $$
            select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
               and exists (select 1 from public.profiles where id = auth.uid() and is_admin);
        $$;
        """
    )
    for table, name, command in _ADMIN_POLICIES:
        op.execute(
            f'drop policy "{name}" on {table}; '
            f'create policy "{name}" on {table} for {command} using (public.is_verified_admin());'
        )
    op.execute(_guard_function("public.is_verified_admin()"))


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(_guard_function("exists (select 1 from public.profiles where id = auth.uid() and is_admin)"))
    for table, name, command in _ADMIN_POLICIES:
        op.execute(
            f'drop policy "{name}" on {table}; '
            f'create policy "{name}" on {table} for {command} using ('
            "exists (select 1 from profiles me where me.id = auth.uid() and me.is_admin = true));"
        )
    op.execute("drop function public.is_verified_admin();")
