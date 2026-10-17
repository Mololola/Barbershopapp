from types import SimpleNamespace

from app.api.account import delete_account


class _CustomerSession:
    """A customer account: no business, so nothing blocks deletion."""

    def __init__(self):
        self.statements = []
        self.committed = False

    def execute(self, statement, params=None):
        self.statements.append(str(statement))
        return SimpleNamespace(mappings=lambda: SimpleNamespace(first=lambda: None))

    def commit(self):
        self.committed = True


def test_deleting_an_account_gives_up_unpaid_payouts_but_keeps_paid_ones():
    session = _CustomerSession()
    delete_account(session, None, "u1")

    payouts, user = session.statements[-2:]
    assert payouts == "delete from payout_requests where profile_id = :user_id and status <> 'paid'"
    assert user == "delete from auth.users where id = :user_id"
    assert session.committed
