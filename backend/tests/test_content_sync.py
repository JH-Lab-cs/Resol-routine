from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fastapi.testclient import TestClient

from app.models.content_sync_enums import ContentSyncEventReason, ContentSyncEventType
from app.models.content_sync_event import ContentSyncEvent

INTERNAL_API_KEY = "unit-test-internal-api-key-value"


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


def _build_revision_fixture(
    *,
    skill: str,
    type_tag: str,
    difficulty: int,
) -> dict[str, object]:
    if skill == "LISTENING":
        turns = [
            {
                "speaker": "Coordinator",
                "text": (
                    "Please check whether the debate room has enough chairs before the "
                    "guests arrive."
                ),
            },
            {
                "speaker": "Volunteer",
                "text": (
                    "I counted them already, but the projector near the stage is still "
                    "disconnected."
                ),
            },
            {
                "speaker": "Coordinator",
                "text": (
                    "Then reconnect it first because the guest speaker will use several "
                    "slides."
                ),
            },
            {
                "speaker": "Volunteer",
                "text": "All right, and I will ask Mina to guide the visitors to the front row.",
            },
        ]
        return {
            "body_text": None,
            "transcript_text": " ".join(turn["text"] for turn in turns),
            "metadata_json": {
                "typeTag": type_tag,
                "difficulty": difficulty,
                "sourcePolicy": "AI_ORIGINAL",
                "ttsPlan": {"voice": "alloy", "speed": 1.0},
                "turns": turns,
                "sentences": [
                    {"id": f"s{index}", "text": turn["text"]}
                    for index, turn in enumerate(turns, start=1)
                ],
            },
            "question": {
                "stem": (
                    "What does the final response most strongly suggest is the volunteer's "
                    "next intention?"
                ),
                "choice_a": "Reconnect the projector and organize visitor seating.",
                "choice_b": "Cancel the debate because there are too few chairs.",
                "choice_c": "Ask the guest speaker to shorten the presentation.",
                "choice_d": "Move every chair out of the debate room immediately.",
                "choice_e": "Tell the visitors to wait outside until lunch ends.",
                "correct_answer": "A",
                "metadata_json": {
                    "typeTag": type_tag,
                    "difficulty": difficulty,
                    "sourcePolicy": "AI_ORIGINAL",
                    "evidenceSentenceIds": ["s3", "s4"],
                    "whyCorrectKo": (
                        "마지막 두 발화가 다음 행동 계획을 보여 준다."
                    ),
                    "whyWrongKoByOption": {"B": "행사를 취소하는 내용이 아니다."},
                },
            },
        }

    body_text = (
        "Many students assume that academic success depends mainly on innate talent. "
        "However, experienced teachers often observe that consistent revision and timely "
        "feedback are equally consequential. "
        "When learners revisit earlier drafts, they begin to detect recurring weaknesses "
        "and refine imprecise reasoning. "
        "Although the process can feel inefficient at first, it cultivates durable habits "
        "that extend beyond a single exam. "
        "Students who practice this routine often become more confident when they meet "
        "unfamiliar questions. "
        "In that sense, the passage suggests that feedback serves a broader purpose than "
        "simple correction. "
        "Instead, it trains students to judge evidence carefully before choosing an answer."
    )
    return {
        "body_text": body_text,
        "transcript_text": None,
        "metadata_json": {
            "typeTag": type_tag,
            "difficulty": difficulty,
            "sourcePolicy": "AI_ORIGINAL",
            "sentences": [
                {
                    "id": "s1",
                    "text": (
                        "Many students assume that academic success depends mainly on "
                        "innate talent."
                    ),
                },
                {
                    "id": "s2",
                    "text": (
                        "However, experienced teachers often observe that consistent "
                        "revision and timely feedback are equally consequential."
                    ),
                },
                {
                    "id": "s3",
                    "text": (
                        "When learners revisit earlier drafts, they begin to detect "
                        "recurring weaknesses and refine imprecise reasoning."
                    ),
                },
                {
                    "id": "s4",
                    "text": (
                        "Although the process can feel inefficient at first, it "
                        "cultivates durable habits that extend beyond a single exam."
                    ),
                },
                {
                    "id": "s5",
                    "text": (
                        "Students who practice this routine often become more confident "
                        "when they meet unfamiliar questions."
                    ),
                },
                {
                    "id": "s6",
                    "text": (
                        "In that sense, the passage suggests that feedback serves a "
                        "broader purpose than simple correction."
                    ),
                },
                {
                    "id": "s7",
                    "text": (
                        "Instead, it trains students to judge evidence carefully before "
                        "choosing an answer."
                    ),
                },
            ],
        },
        "question": {
            "stem": "What does the passage suggest is the main purpose of effective feedback?",
            "choice_a": "It helps students build reflective reasoning habits.",
            "choice_b": "It removes the need to revise earlier drafts.",
            "choice_c": "It proves that natural talent matters more than effort.",
            "choice_d": "It encourages students to memorize answers more quickly.",
            "choice_e": "It shows that unfamiliar questions should be avoided.",
            "correct_answer": "A",
            "metadata_json": {
                "typeTag": type_tag,
                "difficulty": difficulty,
                "sourcePolicy": "AI_ORIGINAL",
                "evidenceSentenceIds": ["s6", "s7"],
                "whyCorrectKo": (
                    "피드백의 목적이 반성적 사고 습관을 기르는 데 있다고 "
                    "요약한다."
                ),
                "whyWrongKoByOption": {"B": "오히려 초안을 다시 보게 한다."},
            },
        },
    }


def _create_revision(
    client: TestClient,
    *,
    unit_id: str,
    revision_code: str,
    skill: str,
    type_tag: str,
    difficulty: int,
) -> dict[str, object]:
    fixture = _build_revision_fixture(skill=skill, type_tag=type_tag, difficulty=difficulty)
    question = fixture["question"]
    response = client.post(
        f"/internal/content/units/{unit_id}/revisions",
        json={
            "revision_code": revision_code,
            "generator_version": "generator-v1",
            "title": f"{skill.title()} title",
            "body_text": fixture["body_text"],
            "transcript_text": fixture["transcript_text"],
            "explanation_text": "Detailed explanation text.",
            "metadata_json": fixture["metadata_json"],
            "questions": [
                {
                    "question_code": f"{revision_code}-q1",
                    "order_index": 1,
                    "stem": question["stem"],
                    "choice_a": question["choice_a"],
                    "choice_b": question["choice_b"],
                    "choice_c": question["choice_c"],
                    "choice_d": question["choice_d"],
                    "choice_e": question["choice_e"],
                    "correct_answer": question["correct_answer"],
                    "explanation": "Option A is correct.",
                    "metadata_json": question["metadata_json"],
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


def _archive_revision(client: TestClient, *, revision_id: str) -> None:
    response = client.post(
        f"/internal/content/revisions/{revision_id}/archive",
        json={"reason": "Retired for sync"},
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text


def _create_published_revision(
    client: TestClient,
    *,
    external_id: str,
    skill: str,
    track: str,
    revision_code: str,
    type_tag: str,
    difficulty: int,
) -> dict[str, str]:
    unit = _create_unit(client, external_id=external_id, skill=skill, track=track)
    revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code=revision_code,
        skill=skill,
        type_tag=type_tag,
        difficulty=difficulty,
    )
    _validate_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))
    _review_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))
    _publish_revision(client, unit_id=str(unit["id"]), revision_id=str(revision["id"]))
    return {"unit_id": str(unit["id"]), "revision_id": str(revision["id"])}


def _set_sync_event_timestamp(
    db_session_factory,
    *,
    revision_id: str,
    timestamp: datetime,
) -> None:
    with db_session_factory() as db:
        rows = (
            db.query(ContentSyncEvent)
            .filter(ContentSyncEvent.revision_id == UUID(revision_id))
            .all()
        )
        for row in rows:
            row.cursor_published_at = timestamp
        db.commit()


def test_sync_returns_upsert_and_detail_fetches_revision(client: TestClient) -> None:
    published = _create_published_revision(
        client,
        external_id="sync-reading-001",
        skill="READING",
        track="H1",
        revision_code="sync-reading-rev-1",
        type_tag="R_MAIN_IDEA",
        difficulty=3,
    )

    sync_response = client.get("/public/content/sync", params={"track": "H1"})
    assert sync_response.status_code == 200, sync_response.text
    sync_body = sync_response.json()
    assert len(sync_body["upserts"]) == 1
    assert sync_body["upserts"][0]["revisionId"] == published["revision_id"]
    assert sync_body["deletes"] == []

    detail_response = client.get(f"/public/content/units/{sync_body['upserts'][0]['revisionId']}")
    assert detail_response.status_code == 200, detail_response.text


def test_sync_cursor_handles_same_timestamp_without_missing_items(
    client: TestClient,
    db_session_factory,
) -> None:
    first = _create_published_revision(
        client,
        external_id="sync-order-1",
        skill="READING",
        track="H2",
        revision_code="sync-order-rev-1",
        type_tag="R_MAIN_IDEA",
        difficulty=2,
    )
    second = _create_published_revision(
        client,
        external_id="sync-order-2",
        skill="READING",
        track="H2",
        revision_code="sync-order-rev-2",
        type_tag="R_DETAIL",
        difficulty=3,
    )
    third = _create_published_revision(
        client,
        external_id="sync-order-3",
        skill="LISTENING",
        track="H2",
        revision_code="sync-order-rev-3",
        type_tag="L_DETAIL",
        difficulty=4,
    )

    shared_timestamp = datetime(2026, 3, 8, 12, 0, tzinfo=UTC)
    _set_sync_event_timestamp(
        db_session_factory,
        revision_id=first["revision_id"],
        timestamp=shared_timestamp,
    )
    _set_sync_event_timestamp(
        db_session_factory,
        revision_id=second["revision_id"],
        timestamp=shared_timestamp,
    )
    _set_sync_event_timestamp(
        db_session_factory,
        revision_id=third["revision_id"],
        timestamp=shared_timestamp,
    )

    seen_revision_ids: list[str] = []
    cursor: str | None = None
    while True:
        params: dict[str, object] = {"track": "H2", "pageSize": 1}
        if cursor is not None:
            params["cursor"] = cursor
        response = client.get("/public/content/sync", params=params)
        assert response.status_code == 200, response.text
        body = response.json()
        seen_revision_ids.extend(item["revisionId"] for item in body["upserts"])
        if not body["hasMore"]:
            break
        cursor = body["nextCursor"]

    assert seen_revision_ids == sorted(
        [
            first["revision_id"],
            second["revision_id"],
            third["revision_id"],
        ]
    )


def test_sync_archive_creates_delete_tombstone(
    client: TestClient,
    db_session_factory,
) -> None:
    published = _create_published_revision(
        client,
        external_id="sync-archive-1",
        skill="READING",
        track="M3",
        revision_code="sync-archive-rev-1",
        type_tag="R_DETAIL",
        difficulty=2,
    )

    first_sync = client.get("/public/content/sync", params={"track": "M3"})
    assert first_sync.status_code == 200, first_sync.text
    cursor = first_sync.json()["nextCursor"]

    _archive_revision(client, revision_id=published["revision_id"])

    delta_response = client.get(
        "/public/content/sync",
        params={"track": "M3", "cursor": cursor},
    )
    assert delta_response.status_code == 200, delta_response.text
    body = delta_response.json()
    assert body["upserts"] == []
    assert len(body["deletes"]) == 1
    assert body["deletes"][0]["revisionId"] == published["revision_id"]
    assert body["deletes"][0]["reason"] == ContentSyncEventReason.ARCHIVED.value

    with db_session_factory() as db:
        events = (
            db.query(ContentSyncEvent)
            .filter(ContentSyncEvent.revision_id == UUID(published["revision_id"]))
            .order_by(ContentSyncEvent.created_at.asc())
            .all()
        )
    assert [event.event_type for event in events] == [
        ContentSyncEventType.UPSERT,
        ContentSyncEventType.DELETE,
    ]


def test_sync_replace_returns_delete_and_upsert_for_same_unit(client: TestClient) -> None:
    unit = _create_unit(client, external_id="sync-replace-unit", skill="READING", track="H3")
    first_revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="sync-replace-rev-1",
        skill="READING",
        type_tag="R_MAIN_IDEA",
        difficulty=3,
    )
    _validate_revision(client, unit_id=str(unit["id"]), revision_id=str(first_revision["id"]))
    _review_revision(client, unit_id=str(unit["id"]), revision_id=str(first_revision["id"]))
    _publish_revision(client, unit_id=str(unit["id"]), revision_id=str(first_revision["id"]))

    first_sync = client.get("/public/content/sync", params={"track": "H3"})
    assert first_sync.status_code == 200, first_sync.text
    cursor = first_sync.json()["nextCursor"]

    second_revision = _create_revision(
        client,
        unit_id=str(unit["id"]),
        revision_code="sync-replace-rev-2",
        skill="READING",
        type_tag="R_DETAIL",
        difficulty=4,
    )
    _validate_revision(client, unit_id=str(unit["id"]), revision_id=str(second_revision["id"]))
    _review_revision(client, unit_id=str(unit["id"]), revision_id=str(second_revision["id"]))
    _publish_revision(client, unit_id=str(unit["id"]), revision_id=str(second_revision["id"]))

    delta_response = client.get(
        "/public/content/sync",
        params={"track": "H3", "cursor": cursor},
    )
    assert delta_response.status_code == 200, delta_response.text
    body = delta_response.json()

    assert [item["revisionId"] for item in body["upserts"]] == [str(second_revision["id"])]
    assert [item["revisionId"] for item in body["deletes"]] == [str(first_revision["id"])]
    assert body["deletes"][0]["reason"] == ContentSyncEventReason.REPLACED.value


def test_sync_invalid_cursor_rejected(client: TestClient) -> None:
    response = client.get(
        "/public/content/sync",
        params={"track": "H1", "cursor": "not-a-valid-cursor"},
    )
    assert response.status_code == 422
    assert response.json()["detail"] == "INVALID_SYNC_CURSOR"
