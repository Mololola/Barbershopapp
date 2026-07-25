import datetime
import uuid

import psycopg
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import get_current_user_id
from app.db.session import get_db
from app.models import Booking, Service, Worker
from app.services.availability import compute_available_slots

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


def _get_opening_hours(db: Session, business_id: uuid.UUID, day_of_week: int) -> dict | None:
    row = db.execute(
        text(
            "select is_closed, open_time, close_time from opening_hours "
            "where business_id = :business_id and day_of_week = :day_of_week"
        ),
        {"business_id": business_id, "day_of_week": day_of_week},
    ).mappings().first()
    return dict(row) if row else None


@router.get("/businesses/{business_id}/availability", response_model=list[datetime.datetime])
def get_availability(
    business_id: uuid.UUID,
    worker_id: uuid.UUID,
    service_id: uuid.UUID,
    date: datetime.date,
    db: Session = Depends(get_db),
    _user_id: str = Depends(get_current_user_id),
) -> list[datetime.datetime]:
    service = _get_active_service(db, business_id, service_id)
    _get_active_worker(db, business_id, worker_id)

    # Monday=0 to match `opening_hours.day_of_week`.
    hours = _get_opening_hours(db, business_id, date.weekday())
    if hours is None:
        return []

    day_start = datetime.datetime.combine(date, datetime.time.min, tzinfo=datetime.UTC)
    day_end = datetime.datetime.combine(date, datetime.time.max, tzinfo=datetime.UTC)
    existing = (
        db.query(Booking)
        .filter(
            Booking.worker_id == worker_id,
            Booking.status == "confirmed",
            Booking.start_time < day_end,
            Booking.end_time > day_start,
        )
        .all()
    )
    booked_ranges = [(b.start_time, b.end_time) for b in existing]

    return compute_available_slots(
        date=date,
        open_time=hours["open_time"],
        close_time=hours["close_time"],
        is_closed=hours["is_closed"],
        duration_minutes=service.duration_minutes,
        booked_ranges=booked_ranges,
        now=datetime.datetime.now(datetime.UTC),
    )


@router.post("/bookings", response_model=BookingResponse, status_code=status.HTTP_201_CREATED)
def create_booking(
    body: BookingCreateRequest,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
) -> Booking:
    service = _get_active_service(db, body.business_id, body.service_id)
    _get_active_worker(db, body.business_id, body.worker_id)

    end_time = body.start_time + datetime.timedelta(minutes=service.duration_minutes)
    booking = Booking(
        business_id=body.business_id,
        worker_id=body.worker_id,
        service_id=body.service_id,
        customer_id=uuid.UUID(user_id),
        start_time=body.start_time,
        end_time=end_time,
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
