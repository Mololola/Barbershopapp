import datetime
import uuid

from sqlalchemy import DateTime, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Review(Base):
    __tablename__ = "reviews"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True)
    booking_id: Mapped[uuid.UUID] = mapped_column(Uuid)
    customer_id: Mapped[uuid.UUID] = mapped_column(Uuid)
    # Stamped by the database on insert (see the e6b2d8f4a1c9 migration),
    # never taken from the app.
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True))
