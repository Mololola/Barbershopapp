import uuid

from sqlalchemy import Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Review(Base):
    __tablename__ = "reviews"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True)
    booking_id: Mapped[uuid.UUID] = mapped_column(Uuid)
    customer_id: Mapped[uuid.UUID] = mapped_column(Uuid)
