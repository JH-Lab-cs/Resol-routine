from __future__ import annotations

from collections.abc import Iterable

import pytest
from fastapi.testclient import TestClient

from app.core.policies import (
    R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS,
    R2_UPLOAD_SIGNED_URL_TTL_SECONDS,
)
from app.services import content_asset_service

INTERNAL_API_KEY = "unit-test-internal-api-key-value"


class FakeR2Signer:
    def __init__(self) -> None:
        self.bucket = "resol-private-bucket"
        self._objects: dict[str, content_asset_service.R2ObjectMetadata] = {}

    def generate_upload_url(self, *, object_key: str, mime_type: str, expires_in_seconds: int) -> str:
        return f"https://fake-r2.local/upload/{object_key}?ttl={expires_in_seconds}&mime={mime_type}"

    def generate_download_url(self, *, object_key: str, expires_in_seconds: int) -> str:
        return f"https://fake-r2.local/download/{object_key}?ttl={expires_in_seconds}"

    def get_object_metadata(self, *, object_key: str) -> content_asset_service.R2ObjectMetadata | None:
        return self._objects.get(object_key)

    def register_object(
        self,
        *,
        object_key: str,
        content_length: int,
        content_type: str,
        etag: str | None = None,
    ) -> None:
        self._objects[object_key] = content_asset_service.R2ObjectMetadata(
            content_length=content_length,
            content_type=content_type,
            etag=etag,
        )


@pytest.fixture()
def fake_r2_signer(monkeypatch: pytest.MonkeyPatch) -> FakeR2Signer:
    signer = FakeR2Signer()
    monkeypatch.setattr(content_asset_service, "get_r2_signer", lambda: signer)
    return signer


def _internal_headers(api_key: str = INTERNAL_API_KEY) -> dict[str, str]:
    return {"X-Internal-Api-Key": api_key}


def _create_unit(
    client: TestClient,
    *,
    external_id: str,
    skill: str = "READING",
    track: str = "M3",
    slug: str | None = None,
) -> dict[str, object]:
    payload: dict[str, object] = {
        "external_id": external_id,
        "skill": skill,
        "track": track,
    }
    if slug is not None:
        payload["slug"] = slug
    response = client.post(
        "/internal/content/units",
        json=payload,
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _create_revision(
    client: TestClient,
    *,
    unit_id: str,
    revision_code: str,
    question_items: Iterable[dict[str, object]],
    generator_version: str = "generator-v1",
    title: str | None = None,
    body_text: str | None = "Reading body text",
    transcript_text: str | None = "Listening transcript text",
    explanation_text: str | None = "English explanation text",
) -> dict[str, object]:
    payload: dict[str, object] = {
        "revision_code": revision_code,
        "generator_version": generator_version,
        "title": title,
        "body_text": body_text,
        "transcript_text": transcript_text,
        "explanation_text": explanation_text,
        "metadata_json": {"source": "pytest"},
        "questions": list(question_items),
    }
    response = client.post(
        f"/internal/content/units/{unit_id}/revisions",
        json=payload,
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _validate_revision(
    client: TestClient,
    *,
    unit_id: str,
    revision_id: str,
    validator_version: str = "validator-v1",
) -> dict[str, object]:
    response = client.post(
        f"/internal/content/units/{unit_id}/revisions/{revision_id}/validate",
        json={"validator_version": validator_version},
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text
    return response.json()


def _review_revision(
    client: TestClient,
    *,
    unit_id: str,
    revision_id: str,
    reviewer_identity: str = "reviewer-jane",
) -> dict[str, object]:
    response = client.post(
        f"/internal/content/units/{unit_id}/revisions/{revision_id}/review",
        json={"reviewer_identity": reviewer_identity},
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text
    return response.json()


def _publish_revision(client: TestClient, *, unit_id: str, revision_id: str) -> dict[str, object]:
    response = client.post(
        f"/internal/content/units/{unit_id}/publish",
        json={"revision_id": revision_id},
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text
    return response.json()


def _question_item(
    *,
    question_code: str,
    order_index: int,
    stem: str,
    correct_answer: str = "A",
    explanation: str | None = "Correct answer explanation",
) -> dict[str, object]:
    return {
        "question_code": question_code,
        "order_index": order_index,
        "stem": stem,
        "choice_a": "Option A",
        "choice_b": "Option B",
        "choice_c": "Option C",
        "choice_d": "Option D",
        "choice_e": "Option E",
        "correct_answer": correct_answer,
        "explanation": explanation,
        "metadata_json": {"difficulty": "medium"},
    }


def test_internal_api_key_missing_and_invalid_rejected(client: TestClient) -> None:
    missing = client.post(
        "/internal/content/units",
        json={"external_id": "unit-key-missing", "skill": "READING", "track": "M3"},
    )
    assert missing.status_code == 401
    assert missing.json()["detail"] == "missing_internal_api_key"

    invalid = client.post(
        "/internal/content/units",
        json={"external_id": "unit-key-invalid", "skill": "READING", "track": "M3"},
        headers=_internal_headers("invalid-key"),
    )
    assert invalid.status_code == 403
    assert invalid.json()["detail"] == "invalid_internal_api_key"


def test_signed_upload_url_issued_with_fixed_ttl(
    client: TestClient,
    fake_r2_signer: FakeR2Signer,
) -> None:
    response = client.post(
        "/internal/content/assets/upload-url",
        json={
            "request_id": "pipeline-upload-1",
            "mime_type": "audio/mpeg",
            "size_bytes": 2048,
            "sha256_hex": "a" * 64,
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["expires_in_seconds"] == R2_UPLOAD_SIGNED_URL_TTL_SECONDS
    assert body["object_key"].startswith("content-assets/")
    assert body["upload_url"].startswith("https://fake-r2.local/upload/")


def test_finalize_nonexistent_object_rejected(
    client: TestClient,
    fake_r2_signer: FakeR2Signer,
) -> None:
    response = client.post(
        "/internal/content/assets/finalize",
        json={
            "object_key": "content-assets/2026/03/02/missing-asset.pdf",
            "mime_type": "application/pdf",
            "size_bytes": 4096,
            "sha256_hex": "b" * 64,
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "asset_object_not_found"


def test_finalize_existing_object_success_and_bucket_mismatch_rejected(
    client: TestClient,
    fake_r2_signer: FakeR2Signer,
) -> None:
    upload = client.post(
        "/internal/content/assets/upload-url",
        json={
            "request_id": "pipeline-upload-2",
            "mime_type": "application/pdf",
            "size_bytes": 4096,
            "sha256_hex": "b" * 64,
        },
        headers=_internal_headers(),
    )
    assert upload.status_code == 200, upload.text
    object_key = upload.json()["object_key"]
    fake_r2_signer.register_object(
        object_key=object_key,
        content_length=4096,
        content_type="application/pdf",
        etag="etag-001",
    )

    finalized = client.post(
        "/internal/content/assets/finalize",
        json={
            "object_key": object_key,
            "mime_type": "application/pdf",
            "size_bytes": 4096,
            "sha256_hex": "b" * 64,
            "etag": "etag-001",
            "bucket": "resol-private-bucket",
        },
        headers=_internal_headers(),
    )
    assert finalized.status_code == 201, finalized.text
    assert finalized.json()["object_key"] == object_key

    invalid_bucket = client.post(
        "/internal/content/assets/finalize",
        json={
            "object_key": object_key,
            "mime_type": "application/pdf",
            "size_bytes": 4096,
            "sha256_hex": "b" * 64,
            "bucket": "wrong-bucket",
        },
        headers=_internal_headers(),
    )
    assert invalid_bucket.status_code == 400
    assert invalid_bucket.json()["detail"] == "invalid_asset_bucket"


def test_asset_download_url_issued_with_fixed_ttl(
    client: TestClient,
    fake_r2_signer: FakeR2Signer,
) -> None:
    upload = client.post(
        "/internal/content/assets/upload-url",
        json={
            "request_id": "pipeline-upload-3",
            "mime_type": "audio/wav",
            "size_bytes": 3000,
            "sha256_hex": "c" * 64,
        },
        headers=_internal_headers(),
    )
    assert upload.status_code == 200, upload.text
    object_key = upload.json()["object_key"]
    fake_r2_signer.register_object(
        object_key=object_key,
        content_length=3000,
        content_type="audio/wav",
    )

    finalized = client.post(
        "/internal/content/assets/finalize",
        json={
            "object_key": object_key,
            "mime_type": "audio/wav",
            "size_bytes": 3000,
            "sha256_hex": "c" * 64,
        },
        headers=_internal_headers(),
    )
    assert finalized.status_code == 201, finalized.text
    asset_id = finalized.json()["id"]

    response = client.get(
        f"/internal/content/assets/{asset_id}/download-url",
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["asset_id"] == asset_id
    assert body["object_key"] == object_key
    assert body["expires_in_seconds"] == R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS
    assert body["download_url"].startswith("https://fake-r2.local/download/")


def test_validate_and_review_endpoint_success(client: TestClient) -> None:
    unit = _create_unit(client, external_id="trace-unit-001", skill="READING", track="H1")
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="trace-r1",
        generator_version="gen-v20260302",
        question_items=[_question_item(question_code="Q001", order_index=1, stem="Trace stem")],
    )
    validated = _validate_revision(
        client,
        unit_id=str(unit["id"]),
        revision_id=str(revision["id"]),
        validator_version="validator-v20260302",
    )
    reviewed = _review_revision(
        client,
        unit_id=str(unit["id"]),
        revision_id=str(revision["id"]),
        reviewer_identity="reviewer-alex",
    )

    assert validated["validator_version"] == "validator-v20260302"
    assert validated["validated_at"] is not None
    assert reviewed["reviewer_identity"] == "reviewer-alex"
    assert reviewed["reviewed_at"] is not None


def test_publish_rejects_without_validate_or_review(client: TestClient) -> None:
    unit = _create_unit(client, external_id="gate-unit-001", skill="READING", track="M3")
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="gate-r1",
        question_items=[_question_item(question_code="Q001", order_index=1, stem="Gate stem")],
    )

    without_validate = client.post(
        f"/internal/content/units/{unit['id']}/publish",
        json={"revision_id": revision["id"]},
        headers=_internal_headers(),
    )
    assert without_validate.status_code == 409
    assert without_validate.json()["detail"] == "revision_not_validated"

    _validate_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))
    without_review = client.post(
        f"/internal/content/units/{unit['id']}/publish",
        json={"revision_id": revision["id"]},
        headers=_internal_headers(),
    )
    assert without_review.status_code == 409
    assert without_review.json()["detail"] == "revision_not_reviewed"


def test_publish_traceability_fields_present_after_publish_and_query(client: TestClient) -> None:
    unit = _create_unit(client, external_id="trace-unit-002", skill="READING", track="M3")
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="trace-r2",
        generator_version="gen-v2",
        question_items=[_question_item(question_code="Q001", order_index=1, stem="Trace stem 2")],
    )
    _validate_revision(
        client,
        unit_id=str(unit["id"]),
        revision_id=str(revision["id"]),
        validator_version="validator-v2",
    )
    _review_revision(
        client,
        unit_id=str(unit["id"]),
        revision_id=str(revision["id"]),
        reviewer_identity="reviewer-kim",
    )
    published = _publish_revision(
        client,
        unit_id=str(unit["id"]),
        revision_id=str(revision["id"]),
    )

    assert published["generator_version"] == "gen-v2"
    assert published["validator_version"] == "validator-v2"
    assert published["reviewer_identity"] == "reviewer-kim"
    assert published["validated_at"] is not None
    assert published["reviewed_at"] is not None
    assert published["published_at"] is not None

    revisions = client.get(
        f"/internal/content/units/{unit['id']}/revisions",
        headers=_internal_headers(),
    )
    assert revisions.status_code == 200, revisions.text
    item = revisions.json()["items"][0]
    assert item["generator_version"] == "gen-v2"
    assert item["validator_version"] == "validator-v2"
    assert item["reviewer_identity"] == "reviewer-kim"


def test_published_revision_validate_rejected(client: TestClient) -> None:
    unit = _create_unit(client, external_id="immut-validate-unit", skill="READING", track="M3")
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="immut-validate-r1",
        question_items=[_question_item(question_code="Q001", order_index=1, stem="Immut stem")],
    )
    _validate_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))
    _review_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))
    _publish_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))

    response = client.post(
        f"/internal/content/units/{unit['id']}/revisions/{revision['id']}/validate",
        json={"validator_version": "validator-v2"},
        headers=_internal_headers(),
    )
    assert response.status_code == 409
    assert response.json()["detail"] == "published_revision_immutable"


def test_published_revision_review_rejected(client: TestClient) -> None:
    unit = _create_unit(client, external_id="immut-review-unit", skill="READING", track="M3")
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="immut-review-r1",
        question_items=[_question_item(question_code="Q001", order_index=1, stem="Immut stem")],
    )
    _validate_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))
    _review_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))
    _publish_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))

    response = client.post(
        f"/internal/content/units/{unit['id']}/revisions/{revision['id']}/review",
        json={"reviewer_identity": "reviewer-next"},
        headers=_internal_headers(),
    )
    assert response.status_code == 409
    assert response.json()["detail"] == "published_revision_immutable"


def test_active_published_revision_republish_rejected(client: TestClient) -> None:
    unit = _create_unit(client, external_id="immut-republish-unit", skill="READING", track="M3")
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="immut-republish-r1",
        question_items=[_question_item(question_code="Q001", order_index=1, stem="Immut stem")],
    )
    _validate_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))
    _review_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))
    _publish_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))

    response = client.post(
        f"/internal/content/units/{unit['id']}/publish",
        json={"revision_id": revision["id"]},
        headers=_internal_headers(),
    )
    assert response.status_code == 409
    assert response.json()["detail"] == "published_revision_already_active"


def test_rejected_immutable_operations_do_not_change_traceability_fields(client: TestClient) -> None:
    unit = _create_unit(client, external_id="immut-unchanged-unit", skill="READING", track="M3")
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="immut-unchanged-r1",
        generator_version="gen-v1",
        question_items=[_question_item(question_code="Q001", order_index=1, stem="Immut stem")],
    )
    _validate_revision(
        client,
        unit_id=str(unit["id"]),
        revision_id=str(revision["id"]),
        validator_version="validator-v1",
    )
    _review_revision(
        client,
        unit_id=str(unit["id"]),
        revision_id=str(revision["id"]),
        reviewer_identity="reviewer-v1",
    )
    _publish_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))

    before_response = client.get(
        f"/internal/content/units/{unit['id']}/revisions",
        headers=_internal_headers(),
    )
    assert before_response.status_code == 200, before_response.text
    before_item = next(item for item in before_response.json()["items"] if item["id"] == revision["id"])

    reject_validate = client.post(
        f"/internal/content/units/{unit['id']}/revisions/{revision['id']}/validate",
        json={"validator_version": "validator-v2"},
        headers=_internal_headers(),
    )
    reject_review = client.post(
        f"/internal/content/units/{unit['id']}/revisions/{revision['id']}/review",
        json={"reviewer_identity": "reviewer-v2"},
        headers=_internal_headers(),
    )
    reject_republish = client.post(
        f"/internal/content/units/{unit['id']}/publish",
        json={"revision_id": revision["id"]},
        headers=_internal_headers(),
    )
    assert reject_validate.status_code == 409
    assert reject_review.status_code == 409
    assert reject_republish.status_code == 409

    after_response = client.get(
        f"/internal/content/units/{unit['id']}/revisions",
        headers=_internal_headers(),
    )
    assert after_response.status_code == 200, after_response.text
    after_item = next(item for item in after_response.json()["items"] if item["id"] == revision["id"])

    assert after_item["validator_version"] == before_item["validator_version"]
    assert after_item["validated_at"] == before_item["validated_at"]
    assert after_item["reviewer_identity"] == before_item["reviewer_identity"]
    assert after_item["reviewed_at"] == before_item["reviewed_at"]
    assert after_item["published_at"] == before_item["published_at"]


def test_rollback_success_updates_active_published_revision_and_query(client: TestClient) -> None:
    unit = _create_unit(client, external_id="rollback-unit-001", skill="READING", track="H2")
    unit_id = str(unit["id"])

    rev1 = _create_revision(
        client,
        unit_id=unit_id,
        revision_code="rollback-r1",
        question_items=[_question_item(question_code="Q001", order_index=1, stem="Old stem")],
    )
    _validate_revision(client, unit_id=unit_id, revision_id=str(rev1["id"]), validator_version="validator-r1")
    _review_revision(client, unit_id=unit_id, revision_id=str(rev1["id"]), reviewer_identity="reviewer-r1")
    _publish_revision(client, unit_id=unit_id, revision_id=str(rev1["id"]))

    rev2 = _create_revision(
        client,
        unit_id=unit_id,
        revision_code="rollback-r2",
        question_items=[_question_item(question_code="Q001", order_index=1, stem="New stem")],
    )
    _validate_revision(client, unit_id=unit_id, revision_id=str(rev2["id"]), validator_version="validator-r2")
    _review_revision(client, unit_id=unit_id, revision_id=str(rev2["id"]), reviewer_identity="reviewer-r2")
    _publish_revision(client, unit_id=unit_id, revision_id=str(rev2["id"]))

    rollback_response = client.post(
        f"/internal/content/units/{unit_id}/rollback",
        json={"target_revision_id": rev1["id"]},
        headers=_internal_headers(),
    )
    assert rollback_response.status_code == 200, rollback_response.text
    rollback_body = rollback_response.json()
    assert rollback_body["previous_published_revision_id"] == rev2["id"]
    assert rollback_body["rolled_back_to_revision_id"] == rev1["id"]

    published_questions = client.get(
        "/internal/content/questions",
        params={"unit_id": unit_id, "published_only": True},
        headers=_internal_headers(),
    )
    assert published_questions.status_code == 200, published_questions.text
    items = published_questions.json()["items"]
    assert len(items) == 1
    assert items[0]["revision_id"] == rev1["id"]
    assert items[0]["question"]["stem"] == "Old stem"


def test_hidden_unicode_identifier_rejected_and_text_rules_enforced(client: TestClient) -> None:
    invalid_unit = client.post(
        "/internal/content/units",
        json={
            "external_id": "hidden\u200b-unit",
            "skill": "READING",
            "track": "M3",
        },
        headers=_internal_headers(),
    )
    assert invalid_unit.status_code == 422
    assert "invalid_hidden_unicode" in invalid_unit.text

    valid_unit = _create_unit(client, external_id="unicode-unit-001", skill="READING", track="M3")

    hidden_body = client.post(
        f"/internal/content/units/{valid_unit['id']}/revisions",
        json={
            "revision_code": "unicode-r-body",
            "generator_version": "gen-1",
            "body_text": "normal text\u200b",
            "transcript_text": "ok",
            "questions": [_question_item(question_code="Q001", order_index=1, stem="Stem ok")],
        },
        headers=_internal_headers(),
    )
    assert hidden_body.status_code == 422
    assert "invalid_hidden_unicode" in hidden_body.text

    hidden_transcript = client.post(
        f"/internal/content/units/{valid_unit['id']}/revisions",
        json={
            "revision_code": "unicode-r-transcript",
            "generator_version": "gen-2",
            "body_text": "ok",
            "transcript_text": "normal\u200b transcript",
            "questions": [_question_item(question_code="Q002", order_index=1, stem="Stem ok")],
        },
        headers=_internal_headers(),
    )
    assert hidden_transcript.status_code == 422
    assert "invalid_hidden_unicode" in hidden_transcript.text

    hidden_explanation = client.post(
        f"/internal/content/units/{valid_unit['id']}/revisions",
        json={
            "revision_code": "unicode-r-explanation",
            "generator_version": "gen-3",
            "body_text": "ok",
            "transcript_text": "ok",
            "explanation_text": "exp\u200b text",
            "questions": [_question_item(question_code="Q003", order_index=1, stem="Stem ok")],
        },
        headers=_internal_headers(),
    )
    assert hidden_explanation.status_code == 422
    assert "invalid_hidden_unicode" in hidden_explanation.text

    normal_multiline = client.post(
        f"/internal/content/units/{valid_unit['id']}/revisions",
        json={
            "revision_code": "unicode-r-valid",
            "generator_version": "gen-4",
            "body_text": "Line one.\nLine two.",
            "transcript_text": "Transcript line one.\nTranscript line two.",
            "explanation_text": "Explanation line one.\nExplanation line two.",
            "questions": [_question_item(question_code="Q004", order_index=1, stem="Stem ok")],
        },
        headers=_internal_headers(),
    )
    assert normal_multiline.status_code == 201, normal_multiline.text
    assert "\n" in normal_multiline.json()["body_text"]


def test_publish_requires_revision_text_by_skill(client: TestClient) -> None:
    listening_unit = _create_unit(client, external_id="listening-rule-001", skill="LISTENING", track="H1")
    listening_revision = _create_revision(
        client,
        unit_id=str(listening_unit["id"]),
        revision_code="listen-r1",
        question_items=[_question_item(question_code="L001", order_index=1, stem="Listening stem")],
        transcript_text=None,
    )
    _validate_revision(
        client,
        unit_id=str(listening_unit["id"]),
        revision_id=str(listening_revision["id"]),
        validator_version="validator-listen",
    )
    _review_revision(
        client,
        unit_id=str(listening_unit["id"]),
        revision_id=str(listening_revision["id"]),
        reviewer_identity="reviewer-listen",
    )
    listening_publish = client.post(
        f"/internal/content/units/{listening_unit['id']}/publish",
        json={"revision_id": listening_revision["id"]},
        headers=_internal_headers(),
    )
    assert listening_publish.status_code == 400
    assert listening_publish.json()["detail"] == "listening_revision_requires_transcript_text"

    reading_unit = _create_unit(client, external_id="reading-rule-001", skill="READING", track="H1")
    reading_revision = _create_revision(
        client,
        unit_id=str(reading_unit["id"]),
        revision_code="read-r1",
        question_items=[_question_item(question_code="R001", order_index=1, stem="Reading stem")],
        body_text=None,
    )
    _validate_revision(
        client,
        unit_id=str(reading_unit["id"]),
        revision_id=str(reading_revision["id"]),
        validator_version="validator-read",
    )
    _review_revision(
        client,
        unit_id=str(reading_unit["id"]),
        revision_id=str(reading_revision["id"]),
        reviewer_identity="reviewer-read",
    )
    reading_publish = client.post(
        f"/internal/content/units/{reading_unit['id']}/publish",
        json={"revision_id": reading_revision["id"]},
        headers=_internal_headers(),
    )
    assert reading_publish.status_code == 400
    assert reading_publish.json()["detail"] == "reading_revision_requires_body_text"
