import pytest
from fastapi.testclient import TestClient

from app.api import jobs
from app.core.config import settings
from app.db.session import get_db
from app.main import app


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(settings, "jobs_secret", "s3cret")
    monkeypatch.setitem(jobs._JOBS, "purge-unconfirmed-signups", lambda db: ["a", "b"])
    app.dependency_overrides[get_db] = lambda: None
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_runs_the_job_with_the_right_secret(client):
    response = client.post("/internal/jobs/purge-unconfirmed-signups", headers={"Authorization": "Bearer s3cret"})

    assert response.status_code == 200
    assert response.json() == {"job": "purge-unconfirmed-signups", "affected": 2}


def test_rejects_a_wrong_or_missing_secret(client):
    assert client.post("/internal/jobs/purge-unconfirmed-signups", headers={"Authorization": "Bearer nope"}).status_code == 401
    assert client.post("/internal/jobs/purge-unconfirmed-signups").status_code == 401


def test_disabled_when_no_secret_is_configured(client, monkeypatch):
    monkeypatch.setattr(settings, "jobs_secret", "")

    response = client.post("/internal/jobs/purge-unconfirmed-signups", headers={"Authorization": "Bearer "})

    assert response.status_code == 401


def test_unknown_job_is_404(client):
    assert client.post("/internal/jobs/nope", headers={"Authorization": "Bearer s3cret"}).status_code == 404
