import datetime
import uuid

from sqlalchemy import Boolean, DateTime, Integer, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class BusinessFinanceAccess(Base):
    __tablename__ = "business_finance_access"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    business_id: Mapped[uuid.UUID] = mapped_column(Uuid)
    grandfathered: Mapped[bool] = mapped_column(Boolean, default=False)
    trial_started_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    trial_ends_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    paid_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    amount_cents: Mapped[int] = mapped_column(Integer, default=4500)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
