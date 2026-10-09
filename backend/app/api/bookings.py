import datetime
import uuid
from zoneinfo import ZoneInfo

import psycopg
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import get_current_user_id
from app.core.cache import cache
from app.core.rate_limit import rate_limit
from app.db.session import get_db
from app.models import Booking, Service, Worker
from app.services.availability import compute_available_slots, working_periods

router = APIRouter()


class BookingCreateRequest(BaseModel):
    business_id: uuid.UUID
    worker_id: uuid.UUID
    service_id: uuid.UUID
    start_time: datetime.datetime


class BookingResponse(BaseModel):
    id: uuid.UUID
    business_id: uuid.UUID
    worker_id: uuid.UUID
    service_id: uuid.UUID
    customer_id: uuid.UUID
    start_time: datetime.datetime
    end_time: datetime.datetime
    status: str
    completed_at: datetime.datetime | None = None


class AvailableSlot(BaseModel):
    worker_id: uuid.UUID
    worker_name: str
    start_time: datetime.datetime


def _get_active_service(db: Session, business_id: uuid.UUID, service_id: uuid.UUID) -> Service:
    service = (
        db.query(Service)
        .filter(Service.id == service_id, Service.business_id == business_id, Service.is_active.is_(True))
        .first()
    )
    if service is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Service not found for this business")
    return service


def _get_active_worker(db: Session, business_id: uuid.UUID, worker_id: uuid.UUID) -> Worker:
    worker = (
        db.query(Worker)
        .filter(Worker.id == worker_id, Worker.business_id == business_id, Worker.is_active.is_(True))
        .first()
    )
    if worker is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Worker not found for this business")
    return worker


# Each of these three reads has an uncached _query_* form and a cached
# _get_* form. get_availability uses the cached ones; create_booking
# deliberately doesn't — the app writes hours straight to Supabase, so the
# backend can't invalidate on change, and a booking accepted against
# up-to-5-minute-old hours could land inside a break the shop just added.
# A stale availability list is harmless (create_booking rechecks); a stale
# booking check isn't.


def _query_opening_hours(db: Session, business_id: uuid.UUID, day_of_week: int) -> dict | None:
    row = db.execute(
        text(
            "select is_closed, open_time, close_time, break_start, break_end from opening_hours "
            "where business_id = :business_id and day_of_week = :day_of_week"
        ),
        {"business_id": business_id, "day_of_week": day_of_week},
    ).mappings().first()
    return dict(row) if row else None


def _get_opening_hours(db: Session, business_id: uuid.UUID, day_of_week: int) -> dict | None:
    # Cached: this is read once per get_availability call and again per
    # active worker inside it (see _effective_hours' caller) — the single
    # highest-amplification read on the app's most frequently hit endpoint.
    return cache.get_or_set(
        f"opening_hours:{business_id}:{day_of_week}",
        lambda: _query_opening_hours(db, business_id, day_of_week),
    )


def _query_worker_schedule(db: Session, worker_id: uuid.UUID, day_of_week: int) -> dict | None:
    row = db.execute(
        text(
            "select is_closed, open_time, close_time, break_start, break_end from worker_schedules "
            "where worker_id = :worker_id and day_of_week = :day_of_week"
        ),
        {"worker_id": worker_id, "day_of_week": day_of_week},
    ).mappings().first()
    return dict(row) if row else None


def _query_worker_schedules(db: Session, worker_ids: list[uuid.UUID], day_of_week: int) -> dict[uuid.UUID, dict]:
    """Every listed worker's own hours for the day, in one query; a worker
    with no row for the day is simply absent."""
    rows = db.execute(
        text(
            "select worker_id, is_closed, open_time, close_time, break_start, break_end from worker_schedules "
            "where worker_id = any(:worker_ids) and day_of_week = :day_of_week"
        ),
        {"worker_ids": worker_ids, "day_of_week": day_of_week},
    ).mappings()
    return {row["worker_id"]: {key: value for key, value in row.items() if key != "worker_id"} for row in rows}


def _get_worker_schedules(
    db: Session, business_id: uuid.UUID, worker_ids: list[uuid.UUID], day_of_week: int
) -> dict[uuid.UUID, dict]:
    # Cached — same reasoning as _get_opening_hours. Keyed on the worker set
    # too, so hiring or removing someone doesn't serve last set's hours.
    workers_key = ",".join(sorted(str(worker_id) for worker_id in worker_ids))
    return cache.get_or_set(
        f"worker_schedules:{business_id}:{day_of_week}:{workers_key}",
        lambda: _query_worker_schedules(db, worker_ids, day_of_week),
    )


def _query_business_time_zone(db: Session, business_id: uuid.UUID) -> ZoneInfo:
    name = db.execute(
        text("select time_zone from businesses where id = :business_id"), {"business_id": business_id}
    ).scalar_one()
    return ZoneInfo(name)


def _get_business_time_zone(db: Session, business_id: uuid.UUID) -> ZoneInfo:
    return cache.get_or_set(f"time_zone:{business_id}", lambda: _query_business_time_zone(db, business_id))


def _effective_hours(worker_schedule: dict | None, business_hours: dict) -> dict:
    """A worker with no schedule of their own (never configured by the
    business) works the business's hours; once a business sets one, that
    worker's own per-day hours — including intentional days off — take over
    completely, with no further cross-check against business hours."""
    return worker_schedule if worker_schedule is not None else business_hours


_CLOSED_HOURS = {"is_closed": True, "open_time": None, "close_time": None, "break_start": None, "break_end": None}


def _slot_rejection_reason(
    start_time: datetime.datetime,
    end_time: datetime.datetime,
    hours: dict,
    now: datetime.datetime,
    tz: datetime.tzinfo,
) -> str | None:
    """None if the slot is bookable, else why not. Mirrors compute_available_slots'
    own rules (see app/services/availability.py) — the EXCLUDE constraint
    only guarantees no double-booking, not that the slot was ever actually
    open or in the future, so create_booking must check this itself rather
    than trusting whatever the client claims is an available slot."""
    if start_time < now:
        return "Cannot book a time in the past"
    periods = working_periods(start_time.astimezone(tz).date(), hours, tz)
    if not any(period_start <= start_time and end_time <= period_end for period_start, period_end in periods):
        return "Outside business hours"
    return None


@router.get("/businesses/{business_id}/availability", response_model=list[AvailableSlot])
def get_availability(
    business_id: uuid.UUID,
    service_id: uuid.UUID,
    date: datetime.date,
    db: Session = Depends(get_db),
    _rate_limit: None = Depends(rate_limit("120/minute")),  # read-heavy — likely re-queried on every date-picker change
    _user_id: str = Depends(get_current_user_id),
) -> list[AvailableSlot]:
    service = _get_active_service(db, business_id, service_id)

    # `date` is a calendar day at the shop, so it's read in the shop's zone.
    # Monday=0 to match `opening_hours.day_of_week`.
    tz = _get_business_time_zone(db, business_id)
    day_of_week = date.weekday()
    business_hours = _get_opening_hours(db, business_id, day_of_week)
    if business_hours is None:
        return []

    workers = db.query(Worker).filter(Worker.business_id == business_id, Worker.is_active.is_(True)).all()
    if not workers:
        return []
    worker_ids = [worker.id for worker in workers]

    day_start = datetime.datetime.combine(date, datetime.time.min, tzinfo=tz)
    day_end = datetime.datetime.combine(date, datetime.time.max, tzinfo=tz)
    now = datetime.datetime.now(datetime.UTC)

    # Schedules and bookings for every worker at once — not two queries per
    # worker. business_id is implied by the workers; filtering on it too
    # lets the (business_id, start_time) index do the work.
    schedules = _get_worker_schedules(db, business_id, worker_ids, day_of_week)
    booked_ranges_by_worker: dict[uuid.UUID, list] = {worker_id: [] for worker_id in worker_ids}
    for booking in (
        db.query(Booking)
        .filter(
            Booking.business_id == business_id,
            Booking.worker_id.in_(worker_ids),
            Booking.status == "confirmed",
            Booking.start_time < day_end,
            Booking.end_time > day_start,
        )
        .all()
    ):
        booked_ranges_by_worker[booking.worker_id].append((booking.start_time, booking.end_time))

    slots: list[AvailableSlot] = []
    for worker in workers:
        hours = _effective_hours(schedules.get(worker.id), business_hours)
        for start_time in compute_available_slots(
            periods=working_periods(date, hours, tz),
            duration_minutes=service.duration_minutes,
            booked_ranges=booked_ranges_by_worker[worker.id],
            now=now,
        ):
            slots.append(AvailableSlot(worker_id=worker.id, worker_name=worker.name, start_time=start_time))

    slots.sort(key=lambda slot: (slot.start_time, slot.worker_name))
    return slots


@router.post("/bookings", response_model=BookingResponse, status_code=status.HTTP_201_CREATED)
def create_booking(
    body: BookingCreateRequest,
    db: Session = Depends(get_db),
    _rate_limit: None = Depends(rate_limit("10/minute")),  # a human can't legitimately create more than this
    user_id: str = Depends(get_current_user_id),
) -> Booking:
    if not _is_business_listed(db, body.business_id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "This business is currently unavailable")

    service = _get_active_service(db, body.business_id, body.service_id)
    _get_active_worker(db, body.business_id, body.worker_id)

    end_time = body.start_time + datetime.timedelta(minutes=service.duration_minutes)

    tz = _query_business_time_zone(db, body.business_id)
    # The weekday at the shop, not in UTC — they differ around midnight.
    day_of_week = body.start_time.astimezone(tz).weekday()
    business_hours = _query_opening_hours(db, body.business_id, day_of_week) or _CLOSED_HOURS
    worker_schedule = _query_worker_schedule(db, body.worker_id, day_of_week)
    hours = _effective_hours(worker_schedule, business_hours)
    rejection_reason = _slot_rejection_reason(
        body.start_time, end_time, hours, datetime.datetime.now(datetime.UTC), tz
    )
    if rejection_reason:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, rejection_reason)

    booking = Booking(
        business_id=body.business_id,
        worker_id=body.worker_id,
        service_id=body.service_id,
        customer_id=uuid.UUID(user_id),
        start_time=body.start_time,
        end_time=end_time,
        price_cents=service.price_cents,
    )
    db.add(booking)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise _map_booking_integrity_error(exc) from exc
    db.refresh(booking)
    return booking


def _map_booking_integrity_error(exc: IntegrityError) -> HTTPException:
    """The exclusion constraint (see docs/architecture.md) is the actual
    concurrency guarantee — this just translates its violation into a
    friendly 409 instead of a raw 500."""
    if isinstance(exc.orig, psycopg.errors.ExclusionViolation):
        return HTTPException(
            status.HTTP_409_CONFLICT,
            "That slot was just taken — please pick another.",
        )
    return HTTPException(status.HTTP_400_BAD_REQUEST, "Could not create booking")


def _is_business_listed(db: Session, business_id: uuid.UUID) -> bool:
    return bool(
        db.execute(
            text("select business_is_listed(:business_id)"),
            {"business_id": business_id},
        ).scalar()
    )


def _is_business_owner(db: Session, business_id: uuid.UUID, user_id: str) -> bool:
    return (
        db.execute(
            text("select 1 from businesses where id = :business_id and owner_id = :user_id"),
            {"business_id": business_id, "user_id": user_id},
        ).first()
        is not None
    )


def _get_booking_or_404(db: Session, booking_id: uuid.UUID) -> Booking:
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if booking is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Booking not found")
    return booking


@router.post("/bookings/{booking_id}/cancel", response_model=BookingResponse)
def cancel_booking(
    booking_id: uuid.UUID,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
) -> Booking:
    booking = _get_booking_or_404(db, booking_id)

    is_customer = str(booking.customer_id) == user_id
    if not (is_customer or _is_business_owner(db, booking.business_id, user_id)):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your booking to cancel")

    booking.status = "cancelled"
    db.commit()
    db.refresh(booking)
    return booking


@router.post("/bookings/{booking_id}/complete", response_model=BookingResponse)
def complete_booking(
    booking_id: uuid.UUID,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
) -> Booking:
    """Only the business can mark a haircut done — see docs/architecture.md
    on why the spec cares about this being business-confirmed (it's what
    unlocks the customer's review prompt, and later, reward eligibility)."""
    booking = _get_booking_or_404(db, booking_id)

    if not _is_business_owner(db, booking.business_id, user_id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your business's booking")
    if booking.status != "confirmed":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Only confirmed bookings can be marked done")

    booking.status = "completed"
    booking.completed_at = datetime.datetime.now(datetime.UTC)
    db.commit()
    db.refresh(booking)
    return booking
