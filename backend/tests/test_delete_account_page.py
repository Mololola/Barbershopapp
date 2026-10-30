from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import app


def test_delete_account_page_is_public_and_explains_both_routes():
    response = TestClient(app).get("/delete-account")

    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "Delete account" in response.text
    assert f"mailto:{settings.support_email}" in response.text


def test_delete_account_page_follows_the_browser_language():
    response = TestClient(app).get("/delete-account", headers={"Accept-Language": "es-ES,es;q=0.9"})

    assert "Eliminar cuenta" in response.text
    assert 'lang="es"' in response.text
