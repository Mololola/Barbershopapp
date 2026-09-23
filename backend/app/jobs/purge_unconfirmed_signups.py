import logging

from sqlalchemy import text
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

UNCONFIRMED_SIGNUP_GRACE_HOURS = 48


def purge_unconfirmed_signups(db: Session) -> list[str]:
    """Deletes auth.users accounts that never confirmed their email within
    the grace period. profiles.id -> auth.users(id) on delete cascade, but
    the app only ever inserts a profiles row once a real (post-confirmation)
    session exists, so an unconfirmed account never has one to cascade —
    this just clears out signups abandoned via a mistyped or unreachable
    email instead of leaving them in the database forever. OAuth sign-ins
    (Google) are auto-confirmed by Supabase at creation, so they're never
    touched by this filter.
    """
    rows = db.execute(
        text(
            "delete from auth.users where email_confirmed_at is null "
            "and created_at < now() - make_interval(hours => :hours) "
            "returning id"
        ),
        {"hours": UNCONFIRMED_SIGNUP_GRACE_HOURS},
    ).fetchall()
    db.commit()
    return [str(row[0]) for row in rows]
