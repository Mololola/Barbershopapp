from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings

# Supabase's connection-pooler URL runs pgbouncer in transaction mode, which is
# incompatible with server-side prepared statements — disable them or queries
# intermittently fail with "prepared statement does not exist" under load.
# pool_pre_ping: the pooler closes idle connections server-side; without this,
# a long-lived process can hand out a dead connection and fail with
# "server closed the connection unexpectedly" instead of transparently
# reconnecting (observed in practice, not just theoretical).
# pool_recycle: proactively retire connections before the pooler's own idle
# timeout gets to them, so pre_ping catches fewer already-dead connections
# instead of relying on it as the only defense.
# pool_use_lifo: reuse the most-recently-returned connection first, so under
# variable load the pool naturally settles toward using fewer distinct
# connections rather than round-robining through all of them — pairs with
# pool_recycle to keep actual connection churn low.
engine = create_engine(
    settings.database_url,
    connect_args={"prepare_threshold": None},
    pool_pre_ping=True,
    pool_size=settings.db_pool_size,
    max_overflow=settings.db_max_overflow,
    pool_recycle=settings.db_pool_recycle_seconds,
    pool_use_lifo=True,
    echo=settings.sql_echo,
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Iterator[Session]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
