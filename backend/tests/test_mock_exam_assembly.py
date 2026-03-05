from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.models.content_asset import ContentAsset
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import (
    Skill,
    SubscriptionFeatureCode,
    SubscriptionPlanStatus,
    Track,
    UserRole,
    UserSubscriptionStatus,
)
from app.models.mock_exam import MockExam
from app.models.mock_exam_revision import MockExamRevision
from app.models.mock_exam_session import MockExamSession
from app.models.parent_child_link import ParentChildLink
from app.models.subscription_plan import SubscriptionPlan
from app.models.subscription_plan_feature import SubscriptionPlanFeature
from app.models.user import User
from app.models.user_subscription import UserSubscription
from app.services import content_asset_service
import app.services.mock_exam_delivery_service as mock_exam_delivery_service

INTERNAL_API_KEY = "unit-test-internal-api-key-value"


class FakeR2Signer:
    def __init__(self) -> None:
        self._download_counter = 0

    def generate_download_url(self, *, object_key: str, expires_in_seconds: int) -> str:
        self._download_counter += 1
        return (
            f"https://fake-r2.local/download/{object_key}"
            f"?ttl={expires_in_seconds}&nonce={self._download_counter}"
        )


def _internal_headers(api_key: str = INTERNAL_API_KEY) -> dict[str, str]:
    return {"X-Internal-Api-Key": api_key}


def _register_user(
    client: TestClient,
    *,
    role: str,
    email: str,
    password: str = "SecurePass123!",
    device_id: str = "device-1",
) -> dict[str, object]:
    response = client.post(
        f"/auth/register/{role}",
        json={"email": email, "password": password, "device_id": device_id},
    )
    assert response.status_code == 201, response.text
    return response.json()


def _student_headers(access_token: str) -> dict[str, str]:
    return {"authorization": f"Bearer {access_token}"}


def _grant_student_entitlements(
    db_session_factory,
    *,
    student_id: UUID,
    feature_codes: set[SubscriptionFeatureCode],
) -> None:
    seed = uuid4().hex[:8]
    with db_session_factory() as db:
        parent = User(
            email=f"entitled-parent-{seed}@example.com",
            password_hash="hashed-password",
            role=UserRole.PARENT,
        )
        db.add(parent)
        db.flush()

        db.add(ParentChildLink(parent_id=parent.id, child_id=student_id))

        plan = SubscriptionPlan(
            plan_code=f"plan-{seed}",
            display_name=f"Plan {seed}",
            status=SubscriptionPlanStatus.ACTIVE,
            metadata_json={"seed": seed},
        )
        db.add(plan)
        db.flush()

        for feature_code in feature_codes:
            db.add(
                SubscriptionPlanFeature(
                    subscription_plan_id=plan.id,
                    feature_code=feature_code,
                )
            )

        now = datetime.now(UTC)
        db.add(
            UserSubscription(
                owner_user_id=parent.id,
                subscription_plan_id=plan.id,
                status=UserSubscriptionStatus.ACTIVE,
                starts_at=now - timedelta(days=1),
                ends_at=now + timedelta(days=30),
                grace_ends_at=None,
                canceled_at=None,
                external_billing_ref=None,
                metadata_json={"seed": seed},
            )
        )
        db.commit()


def _create_mock_exam(
    client: TestClient,
    *,
    exam_type: str,
    track: str,
    period_key: str,
    external_id: str,
) -> dict[str, object]:
    response = client.post(
        "/internal/mock-exams",
        json={
            "examType": exam_type,
            "track": track,
            "periodKey": period_key,
            "externalId": external_id,
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _create_mock_exam_revision(
    client: TestClient,
    *,
    exam_id: str,
    title: str,
    items: list[dict[str, object]],
    generator_version: str = "mock-generator-v1",
) -> dict[str, object]:
    response = client.post(
        f"/internal/mock-exams/{exam_id}/revisions",
        json={
            "title": title,
            "instructions": "Read carefully and choose one answer per question.",
            "generatorVersion": generator_version,
            "metadata": {"source": "pytest"},
            "items": items,
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _validate_revision(client: TestClient, *, exam_id: str, revision_id: str) -> dict[str, object]:
    response = client.post(
        f"/internal/mock-exams/{exam_id}/revisions/{revision_id}/validate",
        json={"validatorVersion": "mock-validator-v1"},
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text
    return response.json()


def _review_revision(client: TestClient, *, exam_id: str, revision_id: str) -> dict[str, object]:
    response = client.post(
        f"/internal/mock-exams/{exam_id}/revisions/{revision_id}/review",
        json={"reviewerIdentity": "reviewer-jane"},
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text
    return response.json()


def _publish_revision(client: TestClient, *, exam_id: str, revision_id: str) -> dict[str, object]:
    response = client.post(
        f"/internal/mock-exams/{exam_id}/publish",
        json={"revisionId": revision_id},
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text
    return response.json()


def _seed_published_questions(
    db_session_factory,
    *,
    track: Track,
    listening_count: int,
    reading_count: int,
    include_asset_for_first_listening: bool = False,
) -> list[dict[str, object]]:
    seed = uuid4().hex[:8]
    references: list[dict[str, object]] = []

    with db_session_factory() as db:
        now = datetime.now(UTC)
        shared_asset: ContentAsset | None = None
        if include_asset_for_first_listening:
            shared_asset = ContentAsset(
                object_key=f"content-assets/{seed}/listening-audio.mp3",
                mime_type="audio/mpeg",
                size_bytes=2048,
                sha256_hex="a" * 64,
                etag="etag-seed",
                bucket="resol-private-bucket",
            )
            db.add(shared_asset)
            db.flush()

        total = listening_count + reading_count
        for index in range(total):
            skill = Skill.LISTENING if index < listening_count else Skill.READING
            unit = ContentUnit(
                external_id=f"seed-unit-{seed}-{index}",
                slug=f"seed-unit-{seed}-{index}",
                skill=skill,
                track=track,
                lifecycle_status=ContentLifecycleStatus.PUBLISHED,
            )
            db.add(unit)
            db.flush()

            revision = ContentUnitRevision(
                content_unit_id=unit.id,
                revision_no=1,
                revision_code=f"r1-{seed}-{index}",
                generator_version="seed-generator",
                validator_version="seed-validator",
                validated_at=now,
                reviewer_identity="seed-reviewer",
                reviewed_at=now,
                title=f"Seed title {index}",
                body_text="Seed reading body text" if skill == Skill.READING else None,
                transcript_text="Seed listening transcript" if skill == Skill.LISTENING else None,
                explanation_text=None,
                asset_id=shared_asset.id if (shared_asset is not None and index == 0) else None,
                metadata_json={"seed": seed},
                lifecycle_status=ContentLifecycleStatus.PUBLISHED,
                published_at=now,
            )
            db.add(revision)
            db.flush()

            unit.published_revision_id = revision.id

            question = ContentQuestion(
                content_unit_revision_id=revision.id,
                question_code=f"Q-{seed}-{index:03d}",
                order_index=1,
                stem=f"Stem {index}",
                choice_a="Option A",
                choice_b="Option B",
                choice_c="Option C",
                choice_d="Option D",
                choice_e="Option E",
                correct_answer="A",
                explanation="Explanation text",
                metadata_json={"seed": seed},
            )
            db.add(question)
            db.flush()

            references.append(
                {
                    "contentUnitRevisionId": str(revision.id),
                    "contentQuestionId": str(question.id),
                    "questionCode": question.question_code,
                    "skill": skill.value,
                }
            )

        db.commit()

    return references


def _seed_unpublished_question(db_session_factory, *, track: Track) -> dict[str, str]:
    seed = uuid4().hex[:8]
    with db_session_factory() as db:
        unit = ContentUnit(
            external_id=f"unpublished-unit-{seed}",
            slug=f"unpublished-unit-{seed}",
            skill=Skill.READING,
            track=track,
            lifecycle_status=ContentLifecycleStatus.DRAFT,
        )
        db.add(unit)
        db.flush()

        revision = ContentUnitRevision(
            content_unit_id=unit.id,
            revision_no=1,
            revision_code=f"u-r1-{seed}",
            generator_version="seed-generator",
            validator_version=None,
            validated_at=None,
            reviewer_identity=None,
            reviewed_at=None,
            title="Draft revision",
            body_text="Draft body text",
            transcript_text=None,
            explanation_text=None,
            asset_id=None,
            metadata_json={"seed": seed},
            lifecycle_status=ContentLifecycleStatus.DRAFT,
            published_at=None,
        )
        db.add(revision)
        db.flush()

        question = ContentQuestion(
            content_unit_revision_id=revision.id,
            question_code=f"UQ-{seed}",
            order_index=1,
            stem="Draft stem",
            choice_a="A",
            choice_b="B",
            choice_c="C",
            choice_d="D",
            choice_e="E",
            correct_answer="A",
            explanation=None,
            metadata_json={"seed": seed},
        )
        db.add(question)
        db.commit()

    return {
        "contentUnitRevisionId": str(revision.id),
        "contentQuestionId": str(question.id),
    }


def _to_revision_items(references: list[dict[str, object]]) -> list[dict[str, object]]:
    return [
        {
            "orderIndex": index + 1,
            "contentUnitRevisionId": reference["contentUnitRevisionId"],
            "contentQuestionId": reference["contentQuestionId"],
        }
        for index, reference in enumerate(references)
    ]


def _create_weekly_published_exam(
    client: TestClient,
    db_session_factory,
    *,
    track: str,
    period_key: str,
    include_asset_for_first_listening: bool = False,
    external_suffix: str,
) -> tuple[dict[str, object], dict[str, object], list[dict[str, object]]]:
    references = _seed_published_questions(
        db_session_factory,
        track=Track(track),
        listening_count=10,
        reading_count=10,
        include_asset_for_first_listening=include_asset_for_first_listening,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track=track,
        period_key=period_key,
        external_id=f"weekly-{external_suffix}",
    )
    revision = _create_mock_exam_revision(
        client,
        exam_id=str(exam["id"]),
        title=f"Weekly {period_key}",
        items=_to_revision_items(references),
    )
    _validate_revision(client, exam_id=str(exam["id"]), revision_id=str(revision["id"]))
    _review_revision(client, exam_id=str(exam["id"]), revision_id=str(revision["id"]))
    _publish_revision(client, exam_id=str(exam["id"]), revision_id=str(revision["id"]))
    return exam, revision, references


def _create_monthly_published_exam(
    client: TestClient,
    db_session_factory,
    *,
    track: str,
    period_key: str,
    external_suffix: str,
) -> tuple[dict[str, object], dict[str, object], list[dict[str, object]]]:
    references = _seed_published_questions(
        db_session_factory,
        track=Track(track),
        listening_count=17,
        reading_count=28,
    )
    exam = _create_mock_exam(
        client,
        exam_type="MONTHLY",
        track=track,
        period_key=period_key,
        external_id=f"monthly-{external_suffix}",
    )
    revision = _create_mock_exam_revision(
        client,
        exam_id=str(exam["id"]),
        title=f"Monthly {period_key}",
        items=_to_revision_items(references),
    )
    _validate_revision(client, exam_id=str(exam["id"]), revision_id=str(revision["id"]))
    _review_revision(client, exam_id=str(exam["id"]), revision_id=str(revision["id"]))
    _publish_revision(client, exam_id=str(exam["id"]), revision_id=str(revision["id"]))
    return exam, revision, references


def test_internal_api_key_missing_and_invalid_rejected(client: TestClient) -> None:
    missing = client.post(
        "/internal/mock-exams",
        json={"examType": "WEEKLY", "track": "H2", "periodKey": "2026W10", "externalId": "wk-h2-2026w10"},
    )
    assert missing.status_code == 401
    assert missing.json()["detail"] == "missing_internal_api_key"

    invalid = client.post(
        "/internal/mock-exams",
        json={"examType": "WEEKLY", "track": "H2", "periodKey": "2026W10", "externalId": "wk-h2-2026w10"},
        headers=_internal_headers("invalid-key"),
    )
    assert invalid.status_code == 403
    assert invalid.json()["detail"] == "invalid_internal_api_key"


def test_mock_exam_draft_create_and_duplicate_period_reject(client: TestClient) -> None:
    first = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W10",
        external_id="weekly-h2-2026w10",
    )
    assert first["examType"] == "WEEKLY"
    assert first["track"] == "H2"

    duplicate = client.post(
        "/internal/mock-exams",
        json={
            "examType": "WEEKLY",
            "track": "H2",
            "periodKey": "2026W10",
            "externalId": "weekly-h2-2026w10-v2",
        },
        headers=_internal_headers(),
    )
    assert duplicate.status_code == 409
    assert duplicate.json()["detail"] == "mock_exam_period_conflict"


def test_revision_create_success_and_reference_validations(client: TestClient, db_session_factory) -> None:
    references = _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W11",
        external_id="weekly-h2-2026w11",
    )

    created = _create_mock_exam_revision(
        client,
        exam_id=str(exam["id"]),
        title="Weekly 2026W11",
        items=_to_revision_items(references),
    )
    assert created["revisionNo"] == 1
    assert len(created["items"]) == 20

    nonexistent_question = client.post(
        f"/internal/mock-exams/{exam['id']}/revisions",
        json={
            "title": "invalid refs",
            "instructions": "invalid",
            "generatorVersion": "mock-generator-v1",
            "metadata": {},
            "items": [
                {
                    "orderIndex": 1,
                    "contentUnitRevisionId": references[0]["contentUnitRevisionId"],
                    "contentQuestionId": str(uuid4()),
                }
            ],
        },
        headers=_internal_headers(),
    )
    assert nonexistent_question.status_code == 400
    assert nonexistent_question.json()["detail"] == "content_question_not_found"

    unpublished_ref = _seed_unpublished_question(db_session_factory, track=Track.H2)
    unpublished = client.post(
        f"/internal/mock-exams/{exam['id']}/revisions",
        json={
            "title": "invalid unpublished refs",
            "instructions": "invalid",
            "generatorVersion": "mock-generator-v1",
            "metadata": {},
            "items": [
                {
                    "orderIndex": 1,
                    "contentUnitRevisionId": unpublished_ref["contentUnitRevisionId"],
                    "contentQuestionId": unpublished_ref["contentQuestionId"],
                }
            ],
        },
        headers=_internal_headers(),
    )
    assert unpublished.status_code == 409
    assert unpublished.json()["detail"] == "content_revision_not_published"


def test_revision_create_duplicate_order_and_duplicate_question_rejected(
    client: TestClient,
    db_session_factory,
) -> None:
    references = _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W12",
        external_id="weekly-h2-2026w12",
    )

    duplicate_order = client.post(
        f"/internal/mock-exams/{exam['id']}/revisions",
        json={
            "title": "dup-order",
            "instructions": "dup-order",
            "generatorVersion": "mock-generator-v1",
            "metadata": {},
            "items": [
                {
                    "orderIndex": 1,
                    "contentUnitRevisionId": references[0]["contentUnitRevisionId"],
                    "contentQuestionId": references[0]["contentQuestionId"],
                },
                {
                    "orderIndex": 1,
                    "contentUnitRevisionId": references[1]["contentUnitRevisionId"],
                    "contentQuestionId": references[1]["contentQuestionId"],
                },
            ],
        },
        headers=_internal_headers(),
    )
    assert duplicate_order.status_code == 422

    duplicate_question = client.post(
        f"/internal/mock-exams/{exam['id']}/revisions",
        json={
            "title": "dup-question",
            "instructions": "dup-question",
            "generatorVersion": "mock-generator-v1",
            "metadata": {},
            "items": [
                {
                    "orderIndex": 1,
                    "contentUnitRevisionId": references[0]["contentUnitRevisionId"],
                    "contentQuestionId": references[0]["contentQuestionId"],
                },
                {
                    "orderIndex": 2,
                    "contentUnitRevisionId": references[0]["contentUnitRevisionId"],
                    "contentQuestionId": references[0]["contentQuestionId"],
                },
            ],
        },
        headers=_internal_headers(),
    )
    assert duplicate_question.status_code == 422


def test_validate_review_publish_and_active_published_single_revision(
    client: TestClient,
    db_session_factory,
) -> None:
    references = _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W13",
        external_id="weekly-h2-2026w13",
    )

    first_revision = _create_mock_exam_revision(
        client,
        exam_id=str(exam["id"]),
        title="Weekly rev1",
        items=_to_revision_items(references),
    )
    _validate_revision(client, exam_id=str(exam["id"]), revision_id=str(first_revision["id"]))
    _review_revision(client, exam_id=str(exam["id"]), revision_id=str(first_revision["id"]))
    published = _publish_revision(client, exam_id=str(exam["id"]), revision_id=str(first_revision["id"]))
    assert published["publishedRevisionId"] == first_revision["id"]

    second_revision = _create_mock_exam_revision(
        client,
        exam_id=str(exam["id"]),
        title="Weekly rev2",
        items=_to_revision_items(references),
        generator_version="mock-generator-v2",
    )
    _validate_revision(client, exam_id=str(exam["id"]), revision_id=str(second_revision["id"]))
    _review_revision(client, exam_id=str(exam["id"]), revision_id=str(second_revision["id"]))
    _publish_revision(client, exam_id=str(exam["id"]), revision_id=str(second_revision["id"]))

    revisions = client.get(
        f"/internal/mock-exams/{exam['id']}/revisions",
        headers=_internal_headers(),
    )
    assert revisions.status_code == 200, revisions.text
    payload = revisions.json()["items"]
    published_revisions = [item for item in payload if item["lifecycleStatus"] == "PUBLISHED"]
    assert len(published_revisions) == 1
    assert published_revisions[0]["id"] == second_revision["id"]


def test_publish_gate_and_published_immutability_and_rollback(
    client: TestClient,
    db_session_factory,
) -> None:
    references = _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W14",
        external_id="weekly-h2-2026w14",
    )
    rev1 = _create_mock_exam_revision(
        client,
        exam_id=str(exam["id"]),
        title="Weekly rev1",
        items=_to_revision_items(references),
    )

    publish_without_validate = client.post(
        f"/internal/mock-exams/{exam['id']}/publish",
        json={"revisionId": rev1["id"]},
        headers=_internal_headers(),
    )
    assert publish_without_validate.status_code == 409
    assert publish_without_validate.json()["detail"] == "revision_not_validated"

    _validate_revision(client, exam_id=str(exam["id"]), revision_id=str(rev1["id"]))
    publish_without_review = client.post(
        f"/internal/mock-exams/{exam['id']}/publish",
        json={"revisionId": rev1["id"]},
        headers=_internal_headers(),
    )
    assert publish_without_review.status_code == 409
    assert publish_without_review.json()["detail"] == "revision_not_reviewed"

    _review_revision(client, exam_id=str(exam["id"]), revision_id=str(rev1["id"]))
    _publish_revision(client, exam_id=str(exam["id"]), revision_id=str(rev1["id"]))

    published_validate = client.post(
        f"/internal/mock-exams/{exam['id']}/revisions/{rev1['id']}/validate",
        json={"validatorVersion": "mock-validator-v2"},
        headers=_internal_headers(),
    )
    assert published_validate.status_code == 409
    assert published_validate.json()["detail"] == "published_revision_immutable"

    published_review = client.post(
        f"/internal/mock-exams/{exam['id']}/revisions/{rev1['id']}/review",
        json={"reviewerIdentity": "reviewer-jack"},
        headers=_internal_headers(),
    )
    assert published_review.status_code == 409
    assert published_review.json()["detail"] == "published_revision_immutable"

    republish_active = client.post(
        f"/internal/mock-exams/{exam['id']}/publish",
        json={"revisionId": rev1["id"]},
        headers=_internal_headers(),
    )
    assert republish_active.status_code == 409
    assert republish_active.json()["detail"] == "published_revision_already_active"

    rev2 = _create_mock_exam_revision(
        client,
        exam_id=str(exam["id"]),
        title="Weekly rev2",
        items=_to_revision_items(references),
        generator_version="mock-generator-v2",
    )
    _validate_revision(client, exam_id=str(exam["id"]), revision_id=str(rev2["id"]))
    _review_revision(client, exam_id=str(exam["id"]), revision_id=str(rev2["id"]))
    _publish_revision(client, exam_id=str(exam["id"]), revision_id=str(rev2["id"]))

    rollback = client.post(
        f"/internal/mock-exams/{exam['id']}/rollback",
        json={"targetRevisionId": rev1["id"]},
        headers=_internal_headers(),
    )
    assert rollback.status_code == 200, rollback.text
    assert rollback.json()["rolledBackToRevisionId"] == rev1["id"]


def test_student_current_weekly_and_monthly_and_no_current_exam(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    student = _register_user(client, role="student", email="current-student@example.com")
    _grant_student_entitlements(
        db_session_factory,
        student_id=UUID(str(student["user"]["id"])),
        feature_codes={
            SubscriptionFeatureCode.WEEKLY_MOCK_EXAMS,
            SubscriptionFeatureCode.MONTHLY_MOCK_EXAMS,
        },
    )
    token = str(student["access_token"])

    monkeypatch.setattr(
        mock_exam_delivery_service,
        "_now_utc",
        lambda: datetime.fromisoformat("2026-03-03T00:00:00+00:00"),
    )

    _create_weekly_published_exam(
        client,
        db_session_factory,
        track="H2",
        period_key="2026W10",
        external_suffix="current-weekly",
    )
    _create_monthly_published_exam(
        client,
        db_session_factory,
        track="H2",
        period_key="202603",
        external_suffix="current-monthly",
    )

    weekly = client.get(
        "/mock-exams/weekly/current",
        params={"track": "H2"},
        headers=_student_headers(token),
    )
    assert weekly.status_code == 200, weekly.text
    assert weekly.json()["examType"] == "WEEKLY"
    assert weekly.json()["periodKey"] == "2026W10"

    monthly = client.get(
        "/mock-exams/monthly/current",
        params={"track": "H2"},
        headers=_student_headers(token),
    )
    assert monthly.status_code == 200, monthly.text
    assert monthly.json()["examType"] == "MONTHLY"
    assert monthly.json()["periodKey"] == "202603"

    no_current = client.get(
        "/mock-exams/weekly/current",
        params={"track": "H3"},
        headers=_student_headers(token),
    )
    assert no_current.status_code == 404
    assert no_current.json()["detail"] == "current_mock_exam_not_found"


def test_parent_forbidden_for_student_mock_exam_api(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _create_weekly_published_exam(
        client,
        db_session_factory,
        track="H2",
        period_key="2026W11",
        external_suffix="parent-forbidden",
    )
    monkeypatch.setattr(
        mock_exam_delivery_service,
        "_now_utc",
        lambda: datetime.fromisoformat("2026-03-10T00:00:00+00:00"),
    )
    parent = _register_user(client, role="parent", email="mock-parent@example.com")
    response = client.get(
        "/mock-exams/weekly/current",
        params={"track": "H2"},
        headers={"authorization": f"Bearer {parent['access_token']}"},
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "student_role_required"


def test_session_start_idempotent_and_detail_contract(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        mock_exam_delivery_service,
        "_now_utc",
        lambda: datetime.fromisoformat("2026-03-04T00:00:00+00:00"),
    )
    student = _register_user(client, role="student", email="session-student@example.com")
    _grant_student_entitlements(
        db_session_factory,
        student_id=UUID(str(student["user"]["id"])),
        feature_codes={SubscriptionFeatureCode.WEEKLY_MOCK_EXAMS},
    )
    token = str(student["access_token"])
    _exam, revision, _references = _create_weekly_published_exam(
        client,
        db_session_factory,
        track="H2",
        period_key="2026W10",
        external_suffix="session-test",
    )

    first_start = client.post(
        f"/mock-exams/{revision['id']}/sessions",
        headers=_student_headers(token),
    )
    assert first_start.status_code == 200, first_start.text
    first_session = first_start.json()
    assert isinstance(first_session["mockSessionId"], int)
    assert first_session["mockExamRevisionId"] == revision["id"]

    second_start = client.post(
        f"/mock-exams/{revision['id']}/sessions",
        headers=_student_headers(token),
    )
    assert second_start.status_code == 200, second_start.text
    assert second_start.json()["mockSessionId"] == first_session["mockSessionId"]

    detail = client.get(
        f"/mock-exam-sessions/{first_session['mockSessionId']}",
        headers=_student_headers(token),
    )
    assert detail.status_code == 200, detail.text
    body = detail.json()
    assert body["mockSessionId"] == first_session["mockSessionId"]
    assert body["mockExamRevisionId"] == revision["id"]
    assert body["examType"] == "WEEKLY"

    items = body["items"]
    assert len(items) == 20
    order_indexes = [item["orderIndex"] for item in items]
    assert order_indexes == sorted(order_indexes)
    assert isinstance(items[0]["questionId"], str)
    assert "correct_answer" not in items[0]
    assert "explanation" not in items[0]
    assert "correctAnswer" not in items[0]


def test_student_cannot_access_other_student_session(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        mock_exam_delivery_service,
        "_now_utc",
        lambda: datetime.fromisoformat("2026-03-05T00:00:00+00:00"),
    )
    student_one = _register_user(client, role="student", email="session-owner@example.com")
    student_two = _register_user(client, role="student", email="session-other@example.com")
    _grant_student_entitlements(
        db_session_factory,
        student_id=UUID(str(student_one["user"]["id"])),
        feature_codes={SubscriptionFeatureCode.WEEKLY_MOCK_EXAMS},
    )
    _exam, revision, _references = _create_weekly_published_exam(
        client,
        db_session_factory,
        track="H2",
        period_key="2026W10",
        external_suffix="session-access",
    )

    started = client.post(
        f"/mock-exams/{revision['id']}/sessions",
        headers=_student_headers(str(student_one["access_token"])),
    )
    assert started.status_code == 200, started.text
    session_id = started.json()["mockSessionId"]

    forbidden = client.get(
        f"/mock-exam-sessions/{session_id}",
        headers=_student_headers(str(student_two["access_token"])),
    )
    assert forbidden.status_code == 403
    assert forbidden.json()["detail"] == "mock_exam_session_access_forbidden"


def test_asset_download_url_is_fresh_per_session_detail_call(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    signer = FakeR2Signer()
    monkeypatch.setattr(content_asset_service, "get_r2_signer", lambda: signer)
    monkeypatch.setattr(
        mock_exam_delivery_service,
        "_now_utc",
        lambda: datetime.fromisoformat("2026-03-06T00:00:00+00:00"),
    )
    student = _register_user(client, role="student", email="asset-student@example.com")
    _grant_student_entitlements(
        db_session_factory,
        student_id=UUID(str(student["user"]["id"])),
        feature_codes={SubscriptionFeatureCode.WEEKLY_MOCK_EXAMS},
    )
    token = str(student["access_token"])
    _exam, revision, _references = _create_weekly_published_exam(
        client,
        db_session_factory,
        track="H2",
        period_key="2026W10",
        include_asset_for_first_listening=True,
        external_suffix="asset-fresh",
    )

    started = client.post(
        f"/mock-exams/{revision['id']}/sessions",
        headers=_student_headers(token),
    )
    assert started.status_code == 200, started.text
    session_id = started.json()["mockSessionId"]

    first = client.get(f"/mock-exam-sessions/{session_id}", headers=_student_headers(token))
    second = client.get(f"/mock-exam-sessions/{session_id}", headers=_student_headers(token))
    assert first.status_code == 200, first.text
    assert second.status_code == 200, second.text

    first_url = next(
        item["assetDownloadUrl"]
        for item in first.json()["items"]
        if item["assetDownloadUrl"] is not None
    )
    second_url = next(
        item["assetDownloadUrl"]
        for item in second.json()["items"]
        if item["assetDownloadUrl"] is not None
    )
    assert first_url != second_url


def test_current_period_key_uses_kst_boundary_for_weekly_and_monthly(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    student = _register_user(client, role="student", email="kst-boundary@example.com")
    _grant_student_entitlements(
        db_session_factory,
        student_id=UUID(str(student["user"]["id"])),
        feature_codes={
            SubscriptionFeatureCode.WEEKLY_MOCK_EXAMS,
            SubscriptionFeatureCode.MONTHLY_MOCK_EXAMS,
        },
    )
    token = str(student["access_token"])

    _create_weekly_published_exam(
        client,
        db_session_factory,
        track="H2",
        period_key="2026W02",
        external_suffix="kst-weekly-boundary",
    )
    monkeypatch.setattr(
        mock_exam_delivery_service,
        "_now_utc",
        lambda: datetime.fromisoformat("2026-01-04T16:30:00+00:00"),
    )
    weekly = client.get(
        "/mock-exams/weekly/current",
        params={"track": "H2"},
        headers=_student_headers(token),
    )
    assert weekly.status_code == 200, weekly.text
    assert weekly.json()["periodKey"] == "2026W02"

    _create_monthly_published_exam(
        client,
        db_session_factory,
        track="H2",
        period_key="202602",
        external_suffix="kst-monthly-boundary",
    )
    monkeypatch.setattr(
        mock_exam_delivery_service,
        "_now_utc",
        lambda: datetime.fromisoformat("2026-01-31T16:00:00+00:00"),
    )
    monthly = client.get(
        "/mock-exams/monthly/current",
        params={"track": "H2"},
        headers=_student_headers(token),
    )
    assert monthly.status_code == 200, monthly.text
    assert monthly.json()["periodKey"] == "202602"


def test_mock_session_id_is_db_integer_and_linked_to_revision(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        mock_exam_delivery_service,
        "_now_utc",
        lambda: datetime.fromisoformat("2026-03-07T00:00:00+00:00"),
    )
    student = _register_user(client, role="student", email="session-db-id@example.com")
    _grant_student_entitlements(
        db_session_factory,
        student_id=UUID(str(student["user"]["id"])),
        feature_codes={SubscriptionFeatureCode.WEEKLY_MOCK_EXAMS},
    )
    token = str(student["access_token"])
    _exam, revision, _references = _create_weekly_published_exam(
        client,
        db_session_factory,
        track="H2",
        period_key="2026W10",
        external_suffix="session-db-id",
    )

    started = client.post(
        f"/mock-exams/{revision['id']}/sessions",
        headers=_student_headers(token),
    )
    assert started.status_code == 200, started.text
    payload = started.json()
    assert isinstance(payload["mockSessionId"], int)

    with db_session_factory() as db:
        row = db.execute(
            select(MockExamSession).where(MockExamSession.id == payload["mockSessionId"])
        ).scalar_one()
        revision_row = db.get(MockExamRevision, UUID(payload["mockExamRevisionId"]))
        exam_row = db.get(MockExam, revision_row.mock_exam_id) if revision_row is not None else None

    assert row.mock_exam_revision_id == UUID(payload["mockExamRevisionId"])
    assert revision_row is not None
    assert exam_row is not None
