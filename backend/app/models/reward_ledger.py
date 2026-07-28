import datetime
import uuid

from sqlalchemy import DateTime, Integer, String, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class RewardLedger(Base):
    __tablename__ = "reward_ledger"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    customer_id: Mapped[uuid.UUID] = mapped_column(Uuid)
    source: Mapped[str] = mapped_column(String, default="review")
    review_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, default=None)
    amount_cents: Mapped[int] = mapped_column(Integer)
    # server_default tells SQLAlchemy to omit this column from the INSERT
    # entirely so the DB's own `default now()` applies — without it,
    # SQLAlchemy sends an explicit NULL for the unset attribute.
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
