from fastapi.testclient import TestClient

from app.main import app


def test_delete_account_page_is_public_and_explains_both_routes():
    response = TestClient(app).get("/delete-account")

    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "Delete account" in response.text
    assert "mailto:" in response.text
