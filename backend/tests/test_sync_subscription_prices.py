from app.jobs import sync_subscription_prices as job


class _Session:
    """Returns `rows` for the mismatch query and records later updates."""

    def __init__(self, rows):
        self.rows = rows
        self.updates = []

    def execute(self, statement, params=None):
        if str(statement).startswith("update"):
            self.updates.append(params)
        self.params = params
        return self

    def mappings(self):
        return self

    def all(self):
        return self.rows

    def commit(self):
        pass


class _StripeSubscription:
    def __init__(self, subscription_id):
        self.id = subscription_id

    def to_dict(self):
        return {"id": self.id, "items": {"data": [{"id": "si_1", "price": {"currency": "gbp", "product": "prod_1"}}]}}


def test_a_changed_basic_cut_moves_the_subscription_from_its_next_payment(monkeypatch):
    modified = []
    monkeypatch.setattr(job.stripe.Subscription, "retrieve", _StripeSubscription)
    monkeypatch.setattr(job.stripe.Subscription, "modify", lambda sub_id, **kwargs: modified.append((sub_id, kwargs)))

    session = _Session([{"business_id": "b1", "stripe_subscription_id": "sub_1", "amount": 18000}])
    assert job.sync_subscription_prices(session) == ["b1"]

    sub_id, kwargs = modified[0]
    assert sub_id == "sub_1" and kwargs["proration_behavior"] == "none"
    assert kwargs["items"] == [
        {
            "id": "si_1",
            "price_data": {"currency": "gbp", "product": "prod_1", "unit_amount": 18000, "recurring": {"interval": "month"}},
        }
    ]
    assert session.updates == [{"amount": 18000, "business_id": "b1"}]


def test_a_stripe_failure_is_left_for_the_next_run(monkeypatch):
    def fail(*args, **kwargs):
        raise job.stripe.error.APIConnectionError("down")

    monkeypatch.setattr(job.stripe.Subscription, "retrieve", fail)

    session = _Session([{"business_id": "b1", "stripe_subscription_id": "sub_1", "amount": 18000}])
    assert job.sync_subscription_prices(session) == []
    assert session.updates == []


def test_an_owner_change_syncs_only_their_shop():
    session = _Session([])
    assert job.sync_subscription_prices(session, "b1") == []
    assert session.params["business_id"] == "b1"
