from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.api.payouts import PayoutRequestCreate, normalize_iban, request_payout


def test_valid_ibans_are_normalized():
    assert normalize_iban("es91 2100 0418 4502 0005 1332") == "ES9121000418450200051332"
    assert normalize_iban("GB82WEST12345698765432") == "GB82WEST12345698765432"


def test_iban_typos_and_garbage_are_rejected():
    assert normalize_iban("GB82WEST12345698765433") is None
    assert normalize_iban("12345678") is None


class _ScriptedSession:
    """Answers each execute() in turn: the lock, the details lookup, the
    balance query, then the insert."""

    def __init__(self, details, available):
        self.results = [None, details, available, None]
        self.statements = []
        self.committed = False

    def execute(self, statement, params=None):
        self.statements.append((str(statement), params))
        result = self.results[len(self.statements) - 1]
        return SimpleNamespace(first=lambda: result, scalar=lambda: result)

    def commit(self):
        self.committed = True


_DETAILS = SimpleNamespace(account_holder="Ana Ruiz", iban="ES9121000418450200051332")


def test_payout_request_copies_the_bank_details_it_will_be_paid_to():
    session = _ScriptedSession(_DETAILS, available=1000)
    request_payout(PayoutRequestCreate(amount_cents=1000, currency="EUR"), session, "u1")

    insert_statement, insert_params = session.statements[-1]
    # Who it was paid to stays on the record if the account is deleted.
    assert "requester_username" in insert_statement
    assert insert_params == {
        "id": "u1",
        "amount": 1000,
        "currency": "EUR",
        "holder": "Ana Ruiz",
        "iban": "ES9121000418450200051332",
    }
    assert session.committed


def test_payout_request_over_the_currencys_balance_is_refused():
    session = _ScriptedSession(_DETAILS, available=999)
    with pytest.raises(HTTPException) as error:
        request_payout(PayoutRequestCreate(amount_cents=1000, currency="EUR"), session, "u1")
    assert error.value.status_code == 400
    assert not session.committed


def test_payout_request_without_bank_details_is_refused():
    session = _ScriptedSession(None, available=1000)
    with pytest.raises(HTTPException):
        request_payout(PayoutRequestCreate(amount_cents=100, currency="EUR"), session, "u1")
    assert not session.committed
