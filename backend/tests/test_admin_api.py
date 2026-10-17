import pytest
from fastapi import HTTPException

from app.api.admin import require_admin


class _FakeDb:
    """Just enough of a Session for require_admin's single is_admin lookup."""

    def __init__(self, is_admin):
        self._is_admin = is_admin

    def execute(self, *args, **kwargs):
        return self

    def scalar(self):
        return self._is_admin


def test_admin_with_second_factor_is_let_through():
    assert require_admin(_FakeDb(True), {"sub": "user-1", "aal": "aal2"}) == "user-1"


def test_admin_signed_in_with_password_only_is_forbidden():
    with pytest.raises(HTTPException) as exc_info:
        require_admin(_FakeDb(True), {"sub": "user-1", "aal": "aal1"})
    assert exc_info.value.status_code == 403


@pytest.mark.parametrize("is_admin", [False, None])
def test_non_admin_or_missing_profile_is_forbidden(is_admin):
    with pytest.raises(HTTPException) as exc_info:
        require_admin(_FakeDb(is_admin), {"sub": "user-1", "aal": "aal2"})
    assert exc_info.value.status_code == 403
