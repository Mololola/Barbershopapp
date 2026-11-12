import uuid

from app.api.finance import finance_premium_state
from app.core.config import settings


def test_finance_premium_is_on_for_every_shop_while_it_is_free(monkeypatch):
    monkeypatch.setattr(settings, "finance_premium_free", True)

    # No database needed: a shop with no access row still gets Premium.
    state = finance_premium_state(None, uuid.uuid4())

    assert state.has_premium
    assert state.subscribed  # so the app offers neither a trial nor a checkout
    assert state.trial_ends_at is None
