import datetime
import uuid

from sqlalchemy import Boolean, DateTime, Integer, String, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class BusinessSubscription(Base):
    __tablename__ = "business_subscriptions"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    business_id: Mapped[uuid.UUID] = mapped_column(Uuid)
    stripe_customer_id: Mapped[str | None] = mapped_column(String, default=None)
    stripe_subscription_id: Mapped[str | None] = mapped_column(String, default=None)
    monthly_amount_cents: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String, default="incomplete")
    grandfathered: Mapped[bool] = mapped_column(Boolean, default=False)
    suspended_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    current_period_end: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    # server_default, not a Python-side default — see reward_ledger.py for
    # why (omits the column from INSERT so the DB's `default now()` fills
    # it in, instead of SQLAlchemy sending an explicit NULL).
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
