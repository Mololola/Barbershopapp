import hmac

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.rate_limit import limiter
from app.db.session import get_db
from app.jobs.expire_grace_periods import find_and_delete_expired_businesses
from app.jobs.purge_unconfirmed_signups import purge_unconfirmed_signups

router = APIRouter()

# Render's free tier sleeps when idle, so an in-process scheduler can't be
# trusted to fire. A GitHub Actions cron (.github/workflows/scheduled-jobs.yml)
# calls these instead — the request itself wakes the service. Both jobs are
# safe to run more often than needed. A failure raises, so the request 500s
# (logged, and reported to Sentry) and the workflow run fails visibly.
_JOBS = {
    "expire-grace-periods": find_and_delete_expired_businesses,
    "purge-unconfirmed-signups": purge_unconfirmed_signups,
}


def _require_jobs_secret(authorization: str = Header(default="")) -> None:
    if not settings.jobs_secret or not hmac.compare_digest(authorization, f"Bearer {settings.jobs_secret}"):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid jobs secret")


@router.post("/internal/jobs/{job}")
@limiter.exempt
def run_job(
    job: str,
    request: Request,
    db: Session = Depends(get_db),
    _auth: None = Depends(_require_jobs_secret),
) -> dict:
    run = _JOBS.get(job)
    if run is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown job")
    return {"job": job, "affected": len(run(db))}
