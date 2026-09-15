import logging
import sys


def configure_logging() -> None:
    """Every module in this app calls `logging.getLogger(__name__)` and
    assumes something is listening — without this, Python's logging module
    has no handler attached by default, so a bare `logger.warning(...)`
    can silently go nowhere depending on how the process was started.

    This is deliberately minimal: timestamped, leveled, to stderr. It's
    enough to see what's failing while watching `uvicorn` directly or
    tailing a host's captured stderr — it is NOT log aggregation, search,
    or alerting. Once there's a real hosting decision, route this through
    that host's log pipeline (or add Sentry) rather than growing this
    function into one.
    """
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        stream=sys.stderr,
    )
