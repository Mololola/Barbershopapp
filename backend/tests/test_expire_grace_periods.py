from app.jobs.expire_grace_periods import GRACE_PERIOD_DAYS, find_and_delete_expired_businesses


class _Session:
    """Returns one expired business for the selection query and records
    every statement after it."""

    def __init__(self):
        self.statements = []

    def execute(self, statement, params=None):
        self.statements.append((str(statement), params))
        return self

    def mappings(self):
        return self

    def all(self):
        return [{"business_id": "b1", "stripe_subscription_id": None, "finance_subscription_id": None}]

    def commit(self):
        pass


def test_the_60_days_count_from_the_first_failed_payment_not_the_hide_date():
    session = _Session()
    find_and_delete_expired_businesses(session)

    select, params = session.statements[0]
    assert "coalesce(s.suspended_at, business_hidden_since(b.id)) < now()" in select
    assert "business_hidden_since(b.id) is not null" in select
    assert params == {"days": 60} and GRACE_PERIOD_DAYS == 60


def test_earned_review_rewards_are_detached_before_the_shop_is_deleted():
    session = _Session()
    assert find_and_delete_expired_businesses(session) == ["b1"]

    statements = [sql for sql, _ in session.statements[1:]]
    assert "update reward_ledger set review_id = null" in statements[0]
    assert statements[1].startswith("delete from businesses")
