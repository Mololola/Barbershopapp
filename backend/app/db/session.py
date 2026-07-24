from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings

# Supabase's connection-pooler URL runs pgbouncer in transaction mode, which is
# incompatible with server-side prepared statements — disable them or queries
# intermittently fail with "prepared statement does not exist" under load.
engine = create_engine(settings.database_url, connect_args={"prepare_threshold": None})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Iterator[Session]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
