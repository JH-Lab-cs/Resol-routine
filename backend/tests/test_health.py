from datetime import datetime

from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import app


def test_health_endpoint_returns_service_status() -> None:
    client = TestClient(app)

    response = client.get("/health")

    assert response.status_code == 200
    payload = response.json()
    assert payload["service"] == settings.app_name
    assert payload["status"] in {"ok", "degraded"}
    assert payload["database"] in {"up", "down"}
    assert payload["redis"] in {"up", "down"}
    datetime.fromisoformat(payload["timestamp_utc"].replace("Z", "+00:00"))
