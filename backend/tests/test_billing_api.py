from datetime import datetime, timedelta, timezone

from app.api.billing import (
    _invoice_subscription_id,
    _price_from_average,
    _scheduled_cancellation,
    _trial_end_timestamp,
)


def test_price_is_ten_times_the_average_active_service_price():
    assert _price_from_average(2000) == 20000


def test_price_rounds_to_the_nearest_cent():
    assert _price_from_average(1033.4) == 10334


def test_no_active_services_returns_none():
    assert _price_from_average(None) is None










def test_no_trial_grant_returns_none():
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    assert _trial_end_timestamp(None, now) is None


def test_trial_well_in_the_future_returns_its_unix_timestamp():
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    trial_ends_at = now + timedelta(days=30)
    assert _trial_end_timestamp(trial_ends_at, now) == int(trial_ends_at.timestamp())


def test_trial_less_than_48h_out_is_ignored_not_an_error():
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    trial_ends_at = now + timedelta(hours=10)
    assert _trial_end_timestamp(trial_ends_at, now) is None


def test_lapsed_trial_is_ignored():
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    trial_ends_at = now - timedelta(days=5)
    assert _trial_end_timestamp(trial_ends_at, now) is None


def test_trial_exactly_at_the_48h_boundary_is_accepted():
    # Stripe's own rule is "at least 48h" — exactly 48h should pass, not be
    # treated the same as too-close-to-now.
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    trial_ends_at = now + timedelta(hours=48)
    assert _trial_end_timestamp(trial_ends_at, now) == int(trial_ends_at.timestamp())


def test_invoice_subscription_is_read_from_parent_on_current_api_versions():
    invoice = {"parent": {"type": "subscription_details", "subscription_details": {"subscription": "sub_1"}}}
    assert _invoice_subscription_id(invoice) == "sub_1"


def test_invoice_subscription_falls_back_to_the_pre_2025_top_level_field():
    assert _invoice_subscription_id({"subscription": "sub_1"}) == "sub_1"


def test_invoice_without_a_subscription_returns_none():
    assert _invoice_subscription_id({"parent": None}) is None


def _subscription(**fields):
    return {"cancel_at": None, "cancel_at_period_end": False, "items": {"data": [{"current_period_end": 1800}]}, **fields}


def test_no_cancellation_scheduled():
    assert _scheduled_cancellation(_subscription()) is None


def test_cancellation_uses_stripes_cancel_at_when_set():
    assert _scheduled_cancellation(_subscription(cancel_at=1700, cancel_at_period_end=True)) == 1700


def test_cancel_at_period_end_without_cancel_at_uses_the_period_end():
    assert _scheduled_cancellation(_subscription(cancel_at_period_end=True)) == 1800


class _RecordingSession:
    def __init__(self):
        self.params = []

    def execute(self, statement, params=None):
        self.params.append(params)
        return self

    def first(self):
        return None

    def commit(self):
        pass


def test_webhook_hands_handlers_plain_dicts(monkeypatch):
    # stripe-python 13+ objects have no .get, so a real signed event (not a
    # dict passed straight to a handler) is what catches a regression here.
    import json
    import time

    import stripe
    from fastapi.testclient import TestClient

    from app.core.config import settings
    from app.db.session import get_db
    from app.main import app

    secret = "whsec_test"
    monkeypatch.setattr(settings, "stripe_webhook_secret", secret)
    session = _RecordingSession()
    app.dependency_overrides[get_db] = lambda: session
    payload = json.dumps(
        {
            "id": "evt_test",
            "object": "event",
            "type": "checkout.session.completed",
            "data": {
                "object": {
                    "object": "checkout.session",
                    "mode": "subscription",
                    "subscription": "sub_test",
                    "metadata": {"business_id": "b1"},
                }
            },
        }
    )
    timestamp = int(time.time())
    signature = stripe.WebhookSignature._compute_signature(f"{timestamp}.{payload}", secret)
    try:
        response = TestClient(app).post(
            "/webhooks/stripe",
            content=payload,
            headers={"stripe-signature": f"t={timestamp},v1={signature}"},
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert {"sub": "sub_test", "business_id": "b1"} in session.params


def _paid_invoice(amount_paid, metadata):
    return {
        "id": "in_1",
        "amount_paid": amount_paid,
        "currency": "eur",
        "parent": {"subscription_details": {"subscription": "sub_1", "metadata": metadata}},
    }


def test_referrer_is_credited_five_percent_of_a_paid_shop_invoice():
    from app.api.billing import _handle_invoice_payment_succeeded

    session = _RecordingSession()
    _handle_invoice_payment_succeeded(session, _paid_invoice(3000, {"business_id": "b1"}))

    assert {"invoice": "in_1", "amount": 150, "currency": "EUR", "business_id": "b1"} in session.params


def test_finance_premium_and_unpaid_invoices_credit_no_referral():
    from app.api.billing import _credit_referral

    session = _RecordingSession()
    _credit_referral(session, _paid_invoice(999, {"business_id": "b1", "product": "finance_premium"}))
    _credit_referral(session, _paid_invoice(0, {"business_id": "b1"}))

    assert session.params == []


def test_finance_premium_cancellation_is_recorded_on_its_own_row():
    from app.api.billing import _handle_subscription_updated

    session = _RecordingSession()
    _handle_subscription_updated(
        session,
        _subscription(id="sub_fin", status="active", cancel_at=1_800_000_000, metadata={"product": "finance_premium"}),
    )

    assert session.params == [{"sub": "sub_fin", "cancel_at": datetime.fromtimestamp(1_800_000_000, timezone.utc)}]


class _CostSession(_RecordingSession):
    """Answers the current-cost lookup with `current`."""

    def __init__(self, current=None):
        super().__init__()
        self.current = current
        self.statements = []

    def execute(self, statement, params=None):
        self.statements.append(str(statement))
        return super().execute(statement, params)

    def mappings(self):
        return self

    def first(self):
        return self.current


def _cycle_invoice(amount_paid, metadata, billing_reason="subscription_cycle"):
    return {**_paid_invoice(amount_paid, metadata), "billing_reason": billing_reason}


def test_first_paid_invoice_adds_the_subscription_as_a_monthly_cost():
    from app.api.billing import _record_subscription_cost

    session = _CostSession()
    _record_subscription_cost(session, _cycle_invoice(3000, {"business_id": "b1"}, "subscription_create"))

    assert session.params[-1] == {"business_id": "b1", "label": "Shop subscription", "amount": 3000, "sub": "sub_1"}


def test_finance_premium_is_labelled_as_such():
    from app.api.billing import _record_subscription_cost

    session = _CostSession()
    _record_subscription_cost(session, _cycle_invoice(999, {"business_id": "b1", "product": "finance_premium"}))

    assert session.params[-1]["label"] == "Finance Premium"


def test_renewal_at_the_same_amount_changes_nothing():
    from app.api.billing import _record_subscription_cost

    session = _CostSession({"id": "c1", "amount_cents": 3000, "started_this_month": False})
    _record_subscription_cost(session, _cycle_invoice(3000, {"business_id": "b1"}))

    assert len(session.statements) == 1


def test_new_amount_ends_the_old_cost_last_month_and_starts_a_new_one():
    from app.api.billing import _record_subscription_cost

    session = _CostSession({"id": "c1", "amount_cents": 3000, "started_this_month": False})
    _record_subscription_cost(session, _cycle_invoice(3500, {"business_id": "b1"}))

    assert "set ends_on" in session.statements[1] and session.params[1] == {"id": "c1"}
    assert session.params[2]["amount"] == 3500


def test_new_amount_in_the_cost_s_first_month_just_replaces_it():
    from app.api.billing import _record_subscription_cost

    session = _CostSession({"id": "c1", "amount_cents": 3000, "started_this_month": True})
    _record_subscription_cost(session, _cycle_invoice(3500, {"business_id": "b1"}))

    assert session.params[1:] == [{"id": "c1", "amount": 3500}]


def test_trial_and_proration_invoices_add_no_cost():
    from app.api.billing import _record_subscription_cost

    session = _CostSession()
    _record_subscription_cost(session, _cycle_invoice(0, {"business_id": "b1"}, "subscription_create"))
    _record_subscription_cost(session, _cycle_invoice(1234, {"business_id": "b1"}, "subscription_update"))

    assert session.statements == []
