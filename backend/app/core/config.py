from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

# Anchored to this file's location, not the process's cwd — otherwise
# whether .env loads depends on where uvicorn happens to be launched from
# (backend/ vs repo root vs a deployment's working directory).
_ENV_FILE = Path(__file__).resolve().parent.parent.parent / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=_ENV_FILE, extra="ignore")

    database_url: str = "postgresql+psycopg://postgres:postgres@localhost:5432/postgres"
    supabase_url: str = ""
    supabase_service_role_key: str = ""
    stripe_secret_key: str = ""
    stripe_webhook_secret: str = ""

    # Deliberately small — Supabase's free/small-tier max_connections is 60
    # total, shared with its own internal services (Supavisor, PostgREST,
    # pg_cron, auth, ...), which alone already account for a handful before
    # this app connects at all. pool_size + db_max_overflow is this one
    # process's ceiling; a paid tier with a higher max_connections (or
    # running as more than one process) should raise these via .env rather
    # than needing a code change.
    db_pool_size: int = 5
    db_max_overflow: int = 5
    db_pool_recycle_seconds: int = 1800

    # Business hours / worker schedules change a handful of times a year at
    # most, so a few minutes of staleness is a non-issue — see
    # app/core/cache.py for what this actually gates.
    cache_ttl_seconds: int = 300
    cache_max_size: int = 2000


settings = Settings()
