from __future__ import annotations

import json
from uuid import UUID

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

import app.services.tts_generation_service as tts_generation_service
from app.core.config import settings
from app.models.content_asset import ContentAsset
from app.models.content_unit_revision import ContentUnitRevision
from app.models.tts_enums import TTSGenerationJobStatus
from app.models.tts_generation_job import TTSGenerationJob
from app.services import ai_artifact_service
from app.services.tts_generation_service import run_tts_generation_job

INTERNAL_API_KEY = "unit-test-internal-api-key-value"


class FakeAIArtifactStore:
    def __init__(self) -> None:
        self._objects: dict[str, str] = {}

    def put_text_with_object_key(
        self,
        *,
        object_key: str,
        body: str,
        content_type: str = "text/plain",
    ) -> str:
        _ = content_type
        self._objects[object_key] = body
        return object_key

    def put_json_with_object_key(self, *, object_key: str, payload: dict[str, object]) -> str:
        self._objects[object_key] = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        return object_key

    def get_text(self, *, object_key: str) -> str:
        if object_key not in self._objects:
            raise ai_artifact_service.ArtifactStoreError(
                code="artifact_object_not_found",
                message="Artifact object does not exist.",
            )
        return self._objects[object_key]


@pytest.fixture()
def fake_ai_artifact_store(monkeypatch: pytest.MonkeyPatch) -> FakeAIArtifactStore:
    store = FakeAIArtifactStore()
    monkeypatch.setattr(tts_generation_service, "get_ai_artifact_store", lambda: store)
    monkeypatch.setattr(ai_artifact_service, "get_ai_artifact_store", lambda: store)
    monkeypatch.setattr(
        tts_generation_service,
        "_upload_audio_object_to_r2",
        lambda **_: "fake-etag",
    )
    return store


def _internal_headers(api_key: str = INTERNAL_API_KEY) -> dict[str, str]:
    return {"X-Internal-Api-Key": api_key}


def _create_listening_unit(
    client: TestClient,
    *,
    external_id: str,
    track: str = "H1",
) -> dict[str, object]:
    response = client.post(
        "/internal/content/units",
        json={
            "external_id": external_id,
            "slug": f"{external_id}-slug",
            "skill": "LISTENING",
            "track": track,
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _create_revision(
    client: TestClient,
    *,
    unit_id: str,
    revision_code: str,
    transcript_text: str,
) -> dict[str, object]:
    response = client.post(
        f"/internal/content/units/{unit_id}/revisions",
        json={
            "revision_code": revision_code,
            "generator_version": "tts-gen-v1",
            "title": "Listening revision for TTS",
            "body_text": None,
            "transcript_text": transcript_text,
            "explanation_text": "Explanation for listening question.",
            "questions": [
                {
                    "question_code": f"Q-{revision_code}",
                    "order_index": 1,
                    "stem": "What does the speaker emphasize?",
                    "choice_a": "Verify evidence first.",
                    "choice_b": "Ignore all details.",
                    "choice_c": "Memorize only vocabulary.",
                    "choice_d": "Guess without context.",
                    "choice_e": "Skip difficult questions.",
                    "correct_answer": "A",
                    "explanation": "The transcript clearly states evidence verification.",
                    "metadata_json": {"typeTag": "L_DETAIL", "difficulty": 3},
                }
            ],
            "metadata_json": {"source": "pytest-tts"},
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _create_tts_job(
    client: TestClient,
    *,
    revision_id: str,
    provider: str = "fake",
) -> dict[str, object]:
    response = client.post(
        "/internal/ai/tts/jobs",
        json={
            "revisionId": revision_id,
            "provider": provider,
            "model": "fake-tts-model",
            "voice": "alloy",
            "speed": 1.0,
            "forceRegen": False,
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_tts_internal_api_key_missing_or_invalid_rejected(client: TestClient) -> None:
    payload = {
        "revisionId": "f67ed7ee-2bd7-4459-a012-e302f13f79aa",
        "provider": "fake",
        "model": "fake-model",
        "voice": "alloy",
        "speed": 1.0,
    }
    missing = client.post("/internal/ai/tts/jobs", json=payload)
    assert missing.status_code == 401
    assert missing.json()["detail"] == "missing_internal_api_key"

    invalid = client.post(
        "/internal/ai/tts/jobs",
        json=payload,
        headers=_internal_headers("invalid-key"),
    )
    assert invalid.status_code == 403
    assert invalid.json()["detail"] == "invalid_internal_api_key"


def test_tts_job_success_sets_revision_asset(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
) -> None:
    unit = _create_listening_unit(client, external_id="tts-success-unit")
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="tts-success-r1",
        transcript_text="A: Please verify evidence before finalizing.\nB: Understood.",
    )
    created_job = _create_tts_job(client, revision_id=str(revision["id"]))
    created_job_id = UUID(str(created_job["jobId"]))
    assert created_job["status"] == "PENDING"

    with db_session_factory() as db:
        execution = run_tts_generation_job(db, job_id=created_job_id)
        db.commit()
        assert execution.status == TTSGenerationJobStatus.SUCCEEDED

    with db_session_factory() as db:
        refreshed_job = db.get(TTSGenerationJob, created_job_id)
        assert refreshed_job is not None
        assert refreshed_job.status == TTSGenerationJobStatus.SUCCEEDED
        assert refreshed_job.output_asset_id is not None
        assert refreshed_job.artifact_request_key is not None
        assert refreshed_job.artifact_response_key is not None
        assert refreshed_job.artifact_candidate_key is not None
        assert refreshed_job.artifact_validation_key is not None

        refreshed_revision = db.get(ContentUnitRevision, UUID(str(revision["id"])))
        assert refreshed_revision is not None
        assert refreshed_revision.asset_id == refreshed_job.output_asset_id
        assert isinstance(refreshed_revision.metadata_json, dict)
        tts_metadata = refreshed_revision.metadata_json.get("tts")
        assert isinstance(tts_metadata, dict)
        assert tts_metadata["generationJobId"] == str(created_job_id)

        asset = db.get(ContentAsset, refreshed_job.output_asset_id)
        assert asset is not None
        assert asset.mime_type == "audio/mpeg"
        assert asset.object_key.startswith("content-assets/tts/")

    assert created_job["artifactRequestKey"] is None
    assert any(key.endswith("/request.json") for key in fake_ai_artifact_store._objects)


def test_tts_job_rejects_hidden_unicode_in_transcript(
    client: TestClient,
    db_session_factory,
) -> None:
    unit = _create_listening_unit(client, external_id="tts-hidden-unit")
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="tts-hidden-r1",
        transcript_text="A: Transcript is valid before mutation.",
    )
    with db_session_factory() as db:
        revision_row = db.get(ContentUnitRevision, UUID(str(revision["id"])))
        assert revision_row is not None
        revision_row.transcript_text = "A: Hidden\u200b unicode should fail."
        db.commit()

    response = client.post(
        "/internal/ai/tts/jobs",
        json={
            "revisionId": revision["id"],
            "provider": "fake",
            "model": "fake-tts-model",
            "voice": "alloy",
            "speed": 1.0,
            "forceRegen": False,
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 422
    assert response.json()["detail"] == "invalid_hidden_unicode"


def test_tts_provider_not_configured_sets_failed_status(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _ = fake_ai_artifact_store
    unit = _create_listening_unit(client, external_id="tts-openai-missing-key")
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="tts-openai-r1",
        transcript_text="A: The provider key is missing in runtime settings.",
    )
    created_job = _create_tts_job(client, revision_id=str(revision["id"]), provider="openai")
    job_id = UUID(str(created_job["jobId"]))

    monkeypatch.setattr(settings, "ai_generation_api_key", None)
    with db_session_factory() as db:
        execution = run_tts_generation_job(db, job_id=job_id)
        db.commit()
        assert execution.status == TTSGenerationJobStatus.FAILED
        assert execution.error_code == "PROVIDER_NOT_CONFIGURED"

    with db_session_factory() as db:
        job = db.get(TTSGenerationJob, job_id)
        assert job is not None
        assert job.status == TTSGenerationJobStatus.FAILED
        assert job.error_code == "PROVIDER_NOT_CONFIGURED"


def test_tts_duplicate_running_job_is_rejected(client: TestClient) -> None:
    unit = _create_listening_unit(client, external_id="tts-dup-unit")
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="tts-dup-r1",
        transcript_text="A: One active job should block duplicate creation.",
    )
    _create_tts_job(client, revision_id=str(revision["id"]))
    duplicate = client.post(
        "/internal/ai/tts/jobs",
        json={
            "revisionId": revision["id"],
            "provider": "fake",
            "model": "fake-tts-model",
            "voice": "alloy",
            "speed": 1.0,
            "forceRegen": False,
        },
        headers=_internal_headers(),
    )
    assert duplicate.status_code == 409
    assert duplicate.json()["detail"] == "tts_job_already_in_progress"


def test_tts_ensure_audio_returns_existing_asset_noop(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
) -> None:
    _ = fake_ai_artifact_store
    unit = _create_listening_unit(client, external_id="tts-ensure-unit")
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="tts-ensure-r1",
        transcript_text="A: Generate once and then ensure no-op.",
    )
    created_job = _create_tts_job(client, revision_id=str(revision["id"]))

    with db_session_factory() as db:
        _ = run_tts_generation_job(db, job_id=UUID(str(created_job["jobId"])))
        db.commit()

    ensure_response = client.post(
        f"/internal/ai/tts/revisions/{revision['id']}/ensure-audio",
        json={
            "provider": "fake",
            "model": "fake-tts-model",
            "voice": "alloy",
            "speed": 1.0,
            "forceRegen": False,
        },
        headers=_internal_headers(),
    )
    assert ensure_response.status_code == 200, ensure_response.text
    payload = ensure_response.json()
    assert payload["created"] is False
    assert payload["existingAssetId"] is not None
    assert payload["job"] is None


def test_tts_retry_endpoint_resets_failed_job(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _ = fake_ai_artifact_store
    unit = _create_listening_unit(client, external_id="tts-retry-unit")
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="tts-retry-r1",
        transcript_text="A: Retry should clear previous failure metadata.",
    )
    created_job = _create_tts_job(client, revision_id=str(revision["id"]), provider="openai")
    job_id = UUID(str(created_job["jobId"]))

    monkeypatch.setattr(settings, "ai_generation_api_key", None)
    with db_session_factory() as db:
        _ = run_tts_generation_job(db, job_id=job_id)
        db.commit()

    retry = client.post(
        f"/internal/ai/tts/jobs/{job_id}/retry",
        headers=_internal_headers(),
    )
    assert retry.status_code == 200, retry.text
    body = retry.json()
    assert body["status"] == "PENDING"
    assert body["errorCode"] is None
    assert body["errorMessage"] is None


def test_tts_job_persists_expected_status_sequence(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
) -> None:
    _ = fake_ai_artifact_store
    unit = _create_listening_unit(client, external_id="tts-status-unit")
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="tts-status-r1",
        transcript_text="A: Track status transition across run.",
    )
    created_job = _create_tts_job(client, revision_id=str(revision["id"]))
    job_id = UUID(str(created_job["jobId"]))
    assert created_job["status"] == "PENDING"

    with db_session_factory() as db:
        _ = run_tts_generation_job(db, job_id=job_id)
        db.commit()
        status_row = db.execute(
            select(TTSGenerationJob.status).where(TTSGenerationJob.id == job_id)
        ).scalar_one()
    assert status_row == TTSGenerationJobStatus.SUCCEEDED
