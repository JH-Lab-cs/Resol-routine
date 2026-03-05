from __future__ import annotations

from fastapi.testclient import TestClient


def test_http_error_response_includes_error_code(client: TestClient) -> None:
    response = client.get("/internal/content/units")
    assert response.status_code == 401
    body = response.json()
    assert body["detail"] == "missing_internal_api_key"
    assert body["errorCode"] == "missing_internal_api_key"


def test_validation_error_response_includes_error_code(client: TestClient) -> None:
    response = client.post(
        "/auth/register/student",
        json={
            "email": "not-an-email",
            "password": "SecurePass123!",
            "device_id": "test-device",
        },
    )
    assert response.status_code == 422
    body = response.json()
    assert body["errorCode"] == "validation_error"
    assert isinstance(body["detail"], list)
