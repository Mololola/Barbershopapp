import datetime
import uuid

from sqlalchemy import Boolean, DateTime, Integer, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Booking(Base):
    __tablename__ = "bookings"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    business_id: Mapped[uuid.UUID] = mapped_column(Uuid)
    worker_id: Mapped[uuid.UUID] = mapped_column(Uuid)
    service_id: Mapped[uuid.UUID] = mapped_column(Uuid)
    customer_id: Mapped[uuid.UUID] = mapped_column(Uuid)
    start_time: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True))
    end_time: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True))
    status: Mapped[str] = mapped_column(String, default="confirmed")
    # What the customer is charged, frozen at booking time so later price
    # changes don't rewrite past revenue.
    price_cents: Mapped[int] = mapped_column(Integer)
    completed_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    # Completed by the auto_complete_bookings job, not by the shop: still open
    # to correction for a week (see mark_no_show).
    auto_completed: Mapped[bool] = mapped_column(Boolean, default=False)
