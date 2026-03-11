from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient

from app.core.policies import R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS
from app.models.content_asset import ContentAsset
from app.models.content_unit_revision import ContentUnitRevision
from app.services import content_asset_service

INTERNAL_API_KEY = "unit-test-internal-api-key-value"


class FakeR2Signer:
    def generate_download_url(self, *, object_key: str, expires_in_seconds: int) -> str:
        return f"https://fake-r2.local/download/{object_key}?ttl={expires_in_seconds}"


@pytest.fixture()
def fake_r2_signer(monkeypatch: pytest.MonkeyPatch) -> FakeR2Signer:
    signer = FakeR2Signer()
    monkeypatch.setattr(content_asset_service, "get_r2_signer", lambda: signer)
    return signer


def _parse_iso8601(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        return parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def _internal_headers() -> dict[str, str]:
    return {"X-Internal-Api-Key": INTERNAL_API_KEY}


def _create_unit(
    client: TestClient,
    *,
    external_id: str,
    skill: str,
    track: str,
) -> dict[str, object]:
    response = client.post(
        "/internal/content/units",
        json={
            "external_id": external_id,
            "skill": skill,
            "track": track,
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _create_asset(
    db_session_factory,
    *,
    mime_type: str = "audio/mpeg",
) -> str:
    with db_session_factory() as db:
        asset = ContentAsset(
            object_key=f"content-assets/test/{uuid4()}.mp3",
            mime_type=mime_type,
            size_bytes=2048,
            sha256_hex="a" * 64,
            etag="etag-test",
            bucket="resol-private-bucket",
        )
        db.add(asset)
        db.commit()
        return str(asset.id)


def _create_revision(
    client: TestClient,
    *,
    unit_id: str,
    revision_code: str,
    skill: str,
    type_tag: str,
    difficulty: int,
    asset_id: str | None = None,
) -> dict[str, object]:
    is_listening = skill == "LISTENING"
    response = client.post(
        f"/internal/content/units/{unit_id}/revisions",
        json={
            "revision_code": revision_code,
            "generator_version": "generator-v1",
            "title": f"{skill.title()} title",
            "body_text": None if is_listening else "Reading body text for delivery.",
            "transcript_text": "Listening transcript text for delivery." if is_listening else None,
            "explanation_text": "Detailed explanation text.",
            "asset_id": asset_id,
            "metadata_json": {
                "typeTag": type_tag,
                "difficulty": difficulty,
                "sourcePolicy": "AI_ORIGINAL",
                "ttsPlan": {"voice": "alloy", "speed": 1.0} if is_listening else None,
            },
            "questions": [
                {
                    "question_code": f"{revision_code}-q1",
                    "order_index": 1,
                    "stem": "What is the best answer?",
                    "choice_a": "Option A",
                    "choice_b": "Option B",
                    "choice_c": "Option C",
                    "choice_d": "Option D",
                    "choice_e": "Option E",
                    "correct_answer": "A",
                    "explanation": "Option A is correct.",
                    "metadata_json": {
                        "typeTag": type_tag,
                        "difficulty": difficulty,
                        "sourcePolicy": "AI_ORIGINAL",
                        "evidenceSentenceIds": ["s1"],
                        "whyCorrectKo": "정답 근거입니다.",
                        "whyWrongKoByOption": {
                            "B": "오답 이유 B",
                            "C": "오답 이유 C",
                        },
                        "vocabNotesKo": "어휘 메모",
                        "structureNotesKo": "구조 메모",
                    },
                }
            ],
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _validate_revision(client: TestClient, *, unit_id: str, revision_id: str) -> None:
    response = client.post(
        f"/internal/content/units/{unit_id}/revisions/{revision_id}/validate",
        json={"validator_version": "validator-v1"},
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text


def _review_revision(client: TestClient, *, unit_id: str, revision_id: str) -> None:
    response = client.post(
        f"/internal/content/units/{unit_id}/revisions/{revision_id}/review",
        json={"reviewer_identity": "ops:reviewer"},
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text


def _publish_revision(client: TestClient, *, unit_id: str, revision_id: str) -> None:
    response = client.post(
        f"/internal/content/units/{unit_id}/publish",
        json={"revision_id": revision_id},
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text


def _archive_revision(client: TestClient, *, revision_id: str, reason: str = "Retired") -> None:
    response = client.post(
        f"/internal/content/revisions/{revision_id}/archive",
        json={"reason": reason},
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text


def _set_published_at(
    db_session_factory,
    *,
    revision_id: str,
    published_at: datetime,
) -> None:
    with db_session_factory() as db:
        revision = db.get(ContentUnitRevision, UUID(revision_id))
        assert revision is not None
        revision.published_at = published_at
        db.commit()


def _set_revision_metadata(
    db_session_factory,
    *,
    revision_id: str,
    metadata_json: dict[str, object],
) -> None:
    with db_session_factory() as db:
        revision = db.get(ContentUnitRevision, UUID(revision_id))
        assert revision is not None
        revision.metadata_json = metadata_json
        db.commit()


def _set_revision_text_fields(
    db_session_factory,
    *,
    revision_id: str,
    body_text: str | None = None,
    transcript_text: str | None = None,
) -> None:
    with db_session_factory() as db:
        revision = db.get(ContentUnitRevision, UUID(revision_id))
        assert revision is not None
        if body_text is not None:
            revision.body_text = body_text
        if transcript_text is not None:
            revision.transcript_text = transcript_text
        db.commit()


def _create_published_revision(
    client: TestClient,
    db_session_factory,
    *,
    external_id: str,
    skill: str,
    track: str,
    revision_code: str,
    type_tag: str,
    difficulty: int,
    published_at: datetime,
    with_audio: bool = False,
) -> dict[str, str]:
    unit = _create_unit(client, external_id=external_id, skill=skill, track=track)
    asset_id = _create_asset(db_session_factory) if with_audio else None
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code=revision_code,
        skill=skill,
        type_tag=type_tag,
        difficulty=difficulty,
        asset_id=asset_id,
    )
    _validate_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))
    _review_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))
    _publish_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))
    _set_published_at(
        db_session_factory,
        revision_id=str(revision["id"]),
        published_at=published_at,
    )
    return {
        "unit_id": str(unit["id"]),
        "revision_id": str(revision["id"]),
        "asset_id": asset_id or "",
    }


def test_public_content_list_filters_track_and_excludes_non_published(
    client: TestClient,
    db_session_factory,
) -> None:
    published_m3 = _create_published_revision(
        client,
        db_session_factory,
        external_id="delivery-reading-m3",
        skill="READING",
        track="M3",
        revision_code="rev-m3-published",
        type_tag="R_MAIN_IDEA",
        difficulty=2,
        published_at=datetime(2026, 3, 8, 0, 0, tzinfo=UTC),
    )
    _create_published_revision(
        client,
        db_session_factory,
        external_id="delivery-reading-h1",
        skill="READING",
        track="H1",
        revision_code="rev-h1-published",
        type_tag="R_DETAIL",
        difficulty=3,
        published_at=datetime(2026, 3, 8, 1, 0, tzinfo=UTC),
    )

    draft_unit = _create_unit(client, external_id="delivery-draft-m3", skill="READING", track="M3")
    _create_revision(
        client,
        unit_id=str(draft_unit["id"]),
        revision_code="rev-m3-draft",
        skill="READING",
        type_tag="R_DETAIL",
        difficulty=2,
    )

    archived = _create_published_revision(
        client,
        db_session_factory,
        external_id="delivery-archived-m3",
        skill="READING",
        track="M3",
        revision_code="rev-m3-archived",
        type_tag="R_VOCAB",
        difficulty=2,
        published_at=datetime(2026, 3, 8, 2, 0, tzinfo=UTC),
    )
    _archive_revision(client, revision_id=archived["revision_id"])

    response = client.get("/public/content/units", params={"track": "M3"})
    assert response.status_code == 200, response.text

    body = response.json()
    assert body["total"] == 1
    assert [item["revisionId"] for item in body["items"]] == [published_m3["revision_id"]]
    assert body["items"][0]["track"] == "M3"
    assert body["items"][0]["typeTag"] == "R_MAIN_IDEA"
    assert body["items"][0]["hasAudio"] is False


def test_public_content_list_supports_delta_sync_and_deterministic_ordering(
    client: TestClient,
    db_session_factory,
    fake_r2_signer: FakeR2Signer,
) -> None:
    del fake_r2_signer
    first = _create_published_revision(
        client,
        db_session_factory,
        external_id="delivery-order-1",
        skill="READING",
        track="H2",
        revision_code="rev-order-1",
        type_tag="R_MAIN_IDEA",
        difficulty=3,
        published_at=datetime(2026, 3, 8, 0, 0, tzinfo=UTC),
    )
    second = _create_published_revision(
        client,
        db_session_factory,
        external_id="delivery-order-2",
        skill="READING",
        track="H2",
        revision_code="rev-order-2",
        type_tag="R_DETAIL",
        difficulty=2,
        published_at=datetime(2026, 3, 8, 0, 0, tzinfo=UTC),
    )
    third = _create_published_revision(
        client,
        db_session_factory,
        external_id="delivery-order-3",
        skill="LISTENING",
        track="H2",
        revision_code="rev-order-3",
        type_tag="L_DETAIL",
        difficulty=4,
        published_at=datetime(2026, 3, 8, 2, 0, tzinfo=UTC),
        with_audio=True,
    )

    response = client.get("/public/content/units", params={"track": "H2"})
    assert response.status_code == 200, response.text
    items = response.json()["items"]
    expected_same_time = sorted([first["revision_id"], second["revision_id"]])
    assert [item["revisionId"] for item in items[:2]] == expected_same_time
    assert items[2]["revisionId"] == third["revision_id"]

    changed_since = datetime(2026, 3, 8, 0, 30, tzinfo=UTC).isoformat()
    delta_response = client.get(
        "/public/content/units",
        params={"track": "H2", "changedSince": changed_since},
    )
    assert delta_response.status_code == 200, delta_response.text
    delta_body = delta_response.json()
    assert [item["revisionId"] for item in delta_body["items"]] == [third["revision_id"]]
    assert _parse_iso8601(delta_body["nextChangedSince"]) == datetime(
        2026, 3, 8, 2, 0, tzinfo=UTC
    )


def test_public_content_detail_returns_reading_canonical_payload(
    client: TestClient,
    db_session_factory,
) -> None:
    reading = _create_published_revision(
        client,
        db_session_factory,
        external_id="delivery-reading-detail",
        skill="READING",
        track="H1",
        revision_code="rev-reading-detail",
        type_tag="R_MAIN_IDEA",
        difficulty=4,
        published_at=datetime(2026, 3, 8, 3, 0, tzinfo=UTC),
    )

    response = client.get(f"/public/content/units/{reading['revision_id']}")
    assert response.status_code == 200, response.text

    body = response.json()
    assert body["unitId"] == reading["unit_id"]
    assert body["revisionId"] == reading["revision_id"]
    assert body["track"] == "H1"
    assert body["skill"] == "READING"
    assert body["typeTag"] == "R_MAIN_IDEA"
    assert body["difficulty"] == 4
    assert body["contentSourcePolicy"] == "AI_ORIGINAL"
    assert body["bodyText"] == "Reading body text for delivery."
    assert body["transcriptText"] is None
    assert body["asset"] is None
    assert body["question"]["answerKey"] == "A"
    assert body["question"]["evidenceSentenceIds"] == ["s1"]
    assert body["question"]["whyCorrectKo"] == "정답 근거입니다."
    assert body["question"]["whyWrongKoByOption"]["B"] == "오답 이유 B"


def test_public_content_detail_returns_listening_signed_url(
    client: TestClient,
    db_session_factory,
    fake_r2_signer: FakeR2Signer,
) -> None:
    del fake_r2_signer
    listening = _create_published_revision(
        client,
        db_session_factory,
        external_id="delivery-listening-detail",
        skill="LISTENING",
        track="H3",
        revision_code="rev-listening-detail",
        type_tag="L_DETAIL",
        difficulty=5,
        published_at=datetime(2026, 3, 8, 4, 0, tzinfo=UTC),
        with_audio=True,
    )

    response = client.get(f"/public/content/units/{listening['revision_id']}")
    assert response.status_code == 200, response.text

    body = response.json()
    assert body["skill"] == "LISTENING"
    assert body["transcriptText"] == "Listening transcript text for delivery."
    assert body["ttsPlan"] == {"voice": "alloy", "speed": 1.0}
    assert body["asset"]["assetId"] == listening["asset_id"]
    assert body["asset"]["mimeType"] == "audio/mpeg"
    assert body["asset"]["signedUrl"].startswith("https://fake-r2.local/download/")
    assert body["asset"]["expiresInSeconds"] == R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS


def test_public_content_detail_allows_multiline_listening_transcript_without_asset(
    client: TestClient,
    db_session_factory,
) -> None:
    listening = _create_published_revision(
        client,
        db_session_factory,
        external_id="delivery-listening-multiline",
        skill="LISTENING",
        track="M3",
        revision_code="rev-listening-multiline",
        type_tag="L_RESPONSE",
        difficulty=1,
        published_at=datetime(2026, 3, 8, 4, 30, tzinfo=UTC),
        with_audio=False,
    )
    _set_revision_text_fields(
        db_session_factory,
        revision_id=listening["revision_id"],
        transcript_text="Friend: Do you want to try the new cafe?\nYou: Sounds good—let's go.",
    )

    response = client.get(f"/public/content/units/{listening['revision_id']}")
    assert response.status_code == 200, response.text

    body = response.json()
    assert body["skill"] == "LISTENING"
    assert body["asset"] is None
    assert body["transcriptText"] == (
        "Friend: Do you want to try the new cafe?\nYou: Sounds good—let's go."
    )


def test_public_content_detail_rejects_draft_and_archived_revisions(
    client: TestClient,
    db_session_factory,
) -> None:
    draft_unit = _create_unit(
        client,
        external_id="delivery-private-draft",
        skill="READING",
        track="M3",
    )
    draft_revision = _create_revision(
        client,
        unit_id=str(draft_unit["id"]),
        revision_code="rev-private-draft",
        skill="READING",
        type_tag="R_DETAIL",
        difficulty=2,
    )

    archived = _create_published_revision(
        client,
        db_session_factory,
        external_id="delivery-private-archived",
        skill="READING",
        track="M3",
        revision_code="rev-private-archived",
        type_tag="R_VOCAB",
        difficulty=2,
        published_at=datetime(2026, 3, 8, 5, 0, tzinfo=UTC),
    )
    _archive_revision(client, revision_id=archived["revision_id"])

    draft_response = client.get(f"/public/content/units/{draft_revision['id']}")
    assert draft_response.status_code == 404
    assert draft_response.json()["detail"] == "published_content_not_found"

    archived_response = client.get(f"/public/content/units/{archived['revision_id']}")
    assert archived_response.status_code == 404
    assert archived_response.json()["detail"] == "published_content_not_found"


def test_public_content_delivery_detects_invalid_hidden_unicode_in_published_source(
    client: TestClient,
    db_session_factory,
) -> None:
    reading = _create_published_revision(
        client,
        db_session_factory,
        external_id="delivery-invalid-hidden",
        skill="READING",
        track="H2",
        revision_code="rev-invalid-hidden",
        type_tag="R_DETAIL",
        difficulty=3,
        published_at=datetime(2026, 3, 8, 6, 0, tzinfo=UTC),
    )

    _set_revision_metadata(
        db_session_factory,
        revision_id=reading["revision_id"],
        metadata_json={
            "typeTag": "R_DETAIL\u200b",
            "difficulty": 3,
            "sourcePolicy": "AI_ORIGINAL",
        },
    )

    response = client.get(f"/public/content/units/{reading['revision_id']}")
    assert response.status_code == 500
    assert response.json()["detail"] == "published_content_contract_invalid"


def test_public_content_list_supports_skill_and_type_tag_filters(
    client: TestClient,
    db_session_factory,
) -> None:
    _create_published_revision(
        client,
        db_session_factory,
        external_id="delivery-filter-reading",
        skill="READING",
        track="H1",
        revision_code="rev-filter-reading",
        type_tag="R_DETAIL",
        difficulty=2,
        published_at=datetime(2026, 3, 8, 7, 0, tzinfo=UTC),
    )
    target = _create_published_revision(
        client,
        db_session_factory,
        external_id="delivery-filter-listening",
        skill="LISTENING",
        track="H1",
        revision_code="rev-filter-listening",
        type_tag="L_DETAIL",
        difficulty=3,
        published_at=datetime(2026, 3, 8, 8, 0, tzinfo=UTC),
        with_audio=True,
    )

    response = client.get(
        "/public/content/units",
        params={
            "track": "H1",
            "skill": "LISTENING",
            "typeTag": "L_DETAIL",
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["total"] == 1
    assert body["items"][0]["revisionId"] == target["revision_id"]


def test_public_content_list_rejects_hidden_unicode_filter_input(client: TestClient) -> None:
    response = client.get(
        "/public/content/units",
        params={"track": "H2\u200b"},
    )
    assert response.status_code == 422
    detail = response.json()["detail"]
    assert any(error["msg"] == "Value error, invalid_hidden_unicode" for error in detail)
