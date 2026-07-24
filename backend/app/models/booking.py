import datetime
import uuid

from sqlalchemy import DateTime, String, Uuid
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
