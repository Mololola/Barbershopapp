"""hours breaks, business time zone, staff guards

Revision ID: c3e8d51a7b92
Revises: b7c41e9d2f60
Create Date: 2026-09-25 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c3e8d51a7b92'
down_revision: Union[str, Sequence[str], None] = 'b7c41e9d2f60'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        -- One optional break per day (a lunch break, Spain's split
        -- "jornada partida"), on both the shop's hours and a worker's own
        -- schedule. Both ends or neither, strictly inside open..close
        -- (explicit not-nulls: a check passes on NULL, so a comparison
        -- alone would let a half-set break through).
        alter table opening_hours add column break_start time, add column break_end time;
        alter table worker_schedules add column break_start time, add column break_end time;

        alter table opening_hours drop constraint opening_hours_valid_range;
        alter table opening_hours add constraint opening_hours_valid_range check (
            is_closed or (
                open_time is not null and close_time is not null and close_time > open_time
                and (
                    (break_start is null and break_end is null)
                    or (
                        break_start is not null and break_end is not null
                        and break_start > open_time and break_end > break_start and close_time > break_end
                    )
                )
            )
        );
        alter table worker_schedules add constraint worker_schedules_valid_range check (
            is_closed or (
                open_time is not null and close_time is not null and close_time > open_time
                and (
                    (break_start is null and break_end is null)
                    or (
                        break_start is not null and break_end is not null
                        and break_start > open_time and break_end > break_start and close_time > break_end
                    )
                )
            )
        );

        -- Opening hours are wall-clock times in the shop's own zone; the
        -- availability/booking code previously read them as UTC, putting
        -- every UK slot an hour late in summer (two in Spain). Hours are
        -- per business, not per location, so the zone is too — set from
        -- the first location's country (Canary Islands postcodes 35/38 are
        -- an hour behind mainland Spain). Limited to the launch markets'
        -- zones; adding a country means adding its zone here.
        alter table businesses add column time_zone text;
        update businesses b set time_zone = coalesce(
            (
                select case
                    when l.country = 'ES' and left(l.postcode, 2) in ('35', '38') then 'Atlantic/Canary'
                    when l.country = 'ES' then 'Europe/Madrid'
                    else 'Europe/London'
                end
                from locations l where l.business_id = b.id order by l.created_at limit 1
            ),
            'Europe/London'
        );
        alter table businesses
            alter column time_zone set not null,
            add constraint businesses_time_zone_check
                check (time_zone in ('Europe/London', 'Europe/Madrid', 'Atlantic/Canary'));

        -- Taking a worker off the staff (the business removing them, or
        -- acknowledging their leave request) must not strand customers with
        -- a confirmed booking against someone who's gone. Enforced here so
        -- every path is covered, not just the app's. SECURITY DEFINER so
        -- the count sees every booking regardless of the caller's RLS.
        -- Custom SQLSTATE so the app can tell this apart from other errors.
        create function public.workers_block_deactivation_with_upcoming_bookings() returns trigger
            language plpgsql
            security definer
            set search_path = ''
        as $$
        declare
            upcoming integer;
        begin
            select count(*) into upcoming
            from public.bookings
            where worker_id = new.id and status = 'confirmed' and start_time > now();
            if upcoming > 0 then
                raise exception using
                    errcode = 'BB001',
                    message = format(
                        '%s has %s upcoming booking%s — cancel or complete %s first.',
                        new.name, upcoming,
                        case when upcoming = 1 then '' else 's' end,
                        case when upcoming = 1 then 'it' else 'them' end
                    );
            end if;
            return new;
        end;
        $$;

        create trigger workers_block_deactivation_with_upcoming_bookings
            before update of is_active on workers
            for each row when (old.is_active and not new.is_active)
            execute function public.workers_block_deactivation_with_upcoming_bookings();

        -- Inviting someone who's already active staff here would only fail
        -- later, confusingly, when they tried to accept (the one-active-
        -- business-per-profile index).
        create function public.worker_invitations_block_existing_staff() returns trigger
            language plpgsql
            set search_path = ''
        as $$
        begin
            if exists (
                select 1 from public.workers
                where business_id = new.business_id and profile_id = new.worker_profile_id and is_active
            ) then
                raise exception using errcode = 'BB002', message = 'They''re already on your staff.';
            end if;
            return new;
        end;
        $$;

        create trigger worker_invitations_block_existing_staff
            before insert on worker_invitations
            for each row execute function public.worker_invitations_block_existing_staff();
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        drop trigger worker_invitations_block_existing_staff on worker_invitations;
        drop function public.worker_invitations_block_existing_staff();
        drop trigger workers_block_deactivation_with_upcoming_bookings on workers;
        drop function public.workers_block_deactivation_with_upcoming_bookings();

        alter table businesses drop column time_zone;

        alter table worker_schedules drop constraint worker_schedules_valid_range;
        alter table opening_hours drop constraint opening_hours_valid_range;
        alter table opening_hours add constraint opening_hours_valid_range check (
            is_closed or (open_time is not null and close_time is not null and close_time > open_time)
        );
        alter table worker_schedules drop column break_start, drop column break_end;
        alter table opening_hours drop column break_start, drop column break_end;
        """
    )
