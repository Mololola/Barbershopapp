from fastapi.testclient import TestClient

from app.core.i18n import translate
from app.main import app


def test_translates_known_messages_for_spanish_only():
    assert translate("Add your bank details first.", "es") == "Añade antes tus datos bancarios."
    assert translate("Add your bank details first.", "es-ES,es;q=0.9") == "Añade antes tus datos bancarios."
    assert translate("Add your bank details first.", "en") == "Add your bank details first."
    assert translate("Add your bank details first.", None) == "Add your bank details first."
    assert translate("Admins only", "es") == "Admins only"


def test_translates_messages_with_a_count():
    assert translate("Resolve your 1 upcoming booking before deleting your account.", "es") == (
        "Resuelve tu reserva pendiente antes de eliminar tu cuenta."
    )
    assert translate("Resolve your 3 upcoming bookings before deleting your account.", "es") == (
        "Resuelve tus 3 reservas pendientes antes de eliminar tu cuenta."
    )


def test_error_responses_follow_accept_language():
    client = TestClient(app)
    headers = {"Authorization": "Bearer not-a-jwt"}

    english = client.get("/account/unpaid-rewards", headers=headers)
    spanish = client.get("/account/unpaid-rewards", headers={**headers, "Accept-Language": "es"})

    assert english.status_code == spanish.status_code == 401
    assert english.json()["detail"] == "Invalid or expired token"
    assert spanish.json()["detail"] == "Tu sesión ha caducado: vuelve a iniciar sesión."


def test_a_request_with_no_token_is_refused_in_spanish_too():
    response = TestClient(app).get("/account/unpaid-rewards", headers={"Accept-Language": "es"})

    assert response.json()["detail"] == "Tienes que iniciar sesión."
