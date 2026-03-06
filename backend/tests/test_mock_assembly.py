from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fastapi.testclient import TestClient
from sqlalchemy import func, select

import app.services.mock_assembly_service as mock_assembly_service
from app.models.audit_log import AuditLog
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import MockExamType, Skill, Track
from app.models.mock_assembly_job import MockAssemblyJob
from app.models.mock_exam import MockExam
from app.models.mock_exam_revision import MockExamRevision
from app.models.mock_exam_revision_item import MockExamRevisionItem

INTERNAL_API_KEY = "unit-test-internal-api-key-value"


def _internal_headers(api_key: str = INTERNAL_API_KEY) -> dict[str, str]:
    return {"X-Internal-Api-Key": api_key}


def _create_mock_assembly_job(
    client: TestClient,
    *,
    exam_type: str,
    track: str,
    period_key: str,
    dry_run: bool = False,
    force_rebuild: bool = False,
    seed_override: str | None = None,
) -> dict[str, object]:
    payload: dict[str, object] = {
        "examType": exam_type,
        "track": track,
        "periodKey": period_key,
        "dryRun": dry_run,
        "forceRebuild": force_rebuild,
    }
    if seed_override is not None:
        payload["seedOverride"] = seed_override

    response = client.post(
        "/internal/mock-assembly/jobs",
        json=payload,
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _seed_published_questions(
    db_session_factory,
    *,
    track: Track,
    skill: Skill,
    type_tag: str,
    difficulty: int,
    count: int,
    label_prefix: str,
) -> None:
    now = datetime.now(UTC)
    with db_session_factory() as db:
        for index in range(count):
            unit = ContentUnit(
                external_id=f"{label_prefix}-unit-{skill.value}-{type_tag}-{index}",
                slug=f"{label_prefix}-slug-{skill.value}-{type_tag}-{index}",
                skill=skill,
                track=track,
                lifecycle_status=ContentLifecycleStatus.PUBLISHED,
            )
            db.add(unit)
            db.flush()

            revision = ContentUnitRevision(
                content_unit_id=unit.id,
                revision_no=1,
                revision_code=f"{label_prefix}-r-{type_tag}-{index}",
                generator_version="seed-generator-v1",
                validator_version="seed-validator-v1",
                validated_at=now,
                reviewer_identity="seed-reviewer",
                reviewed_at=now,
                title=f"{label_prefix} title {index}",
                body_text="Seed reading body text" if skill == Skill.READING else None,
                transcript_text=(
                    "Seed listening transcript text" if skill == Skill.LISTENING else None
                ),
                explanation_text="Seed explanation text",
                asset_id=None,
                metadata_json={"seed": label_prefix},
                lifecycle_status=ContentLifecycleStatus.PUBLISHED,
                published_at=now,
            )
            db.add(revision)
            db.flush()

            unit.published_revision_id = revision.id

            question = ContentQuestion(
                content_unit_revision_id=revision.id,
                question_code=f"{label_prefix}-Q-{type_tag}-{index}",
                order_index=1,
                stem=f"Stem {label_prefix} {index}",
                choice_a="Option A",
                choice_b="Option B",
                choice_c="Option C",
                choice_d="Option D",
                choice_e="Option E",
                correct_answer="A",
                explanation="Explanation",
                metadata_json={
                    "typeTag": type_tag,
                    "difficulty": difficulty,
                },
            )
            db.add(question)

        db.commit()


def _seed_weekly_assembly_pool(db_session_factory, *, track: Track, label_prefix: str) -> None:
    listening_rows = [
        ("L_GIST", 3, 4),
        ("L_DETAIL", 3, 4),
        ("L_INTENT", 2, 4),
    ]
    reading_rows = [
        ("R_MAIN_IDEA", 3, 3),
        ("R_DETAIL", 3, 3),
        ("R_INFERENCE", 4, 2),
        ("R_BLANK", 3, 2),
    ]

    for type_tag, difficulty, count in listening_rows:
        _seed_published_questions(
            db_session_factory,
            track=track,
            skill=Skill.LISTENING,
            type_tag=type_tag,
            difficulty=difficulty,
            count=count,
            label_prefix=label_prefix,
        )
    for type_tag, difficulty, count in reading_rows:
        _seed_published_questions(
            db_session_factory,
            track=track,
            skill=Skill.READING,
            type_tag=type_tag,
            difficulty=difficulty,
            count=count,
            label_prefix=label_prefix,
        )


def _seed_monthly_assembly_pool(db_session_factory, *, track: Track, label_prefix: str) -> None:
    listening_rows = [
        ("L_GIST", 3, 5),
        ("L_DETAIL", 4, 5),
        ("L_INTENT", 3, 5),
        ("L_LONG_TALK", 4, 5),
    ]
    reading_rows = [
        ("R_MAIN_IDEA", 4, 6),
        ("R_DETAIL", 3, 6),
        ("R_INFERENCE", 4, 6),
        ("R_BLANK", 4, 6),
        ("R_ORDER", 3, 6),
        ("R_INSERTION", 4, 6),
    ]

    for type_tag, difficulty, count in listening_rows:
        _seed_published_questions(
            db_session_factory,
            track=track,
            skill=Skill.LISTENING,
            type_tag=type_tag,
            difficulty=difficulty,
            count=count,
            label_prefix=label_prefix,
        )
    for type_tag, difficulty, count in reading_rows:
        _seed_published_questions(
            db_session_factory,
            track=track,
            skill=Skill.READING,
            type_tag=type_tag,
            difficulty=difficulty,
            count=count,
            label_prefix=label_prefix,
        )


def test_mock_assembly_internal_api_key_required(client: TestClient) -> None:
    payload = {
        "examType": "WEEKLY",
        "track": "H2",
        "periodKey": "2026W10",
        "dryRun": True,
        "forceRebuild": False,
    }
    missing = client.post("/internal/mock-assembly/jobs", json=payload)
    assert missing.status_code == 401
    assert missing.json()["detail"] == "missing_internal_api_key"

    invalid = client.post(
        "/internal/mock-assembly/jobs",
        json=payload,
        headers=_internal_headers("invalid-key"),
    )
    assert invalid.status_code == 403
    assert invalid.json()["detail"] == "invalid_internal_api_key"


def test_weekly_assembly_materializes_draft_and_keeps_exam_unpublished(
    client: TestClient,
    db_session_factory,
) -> None:
    _seed_weekly_assembly_pool(db_session_factory, track=Track.H2, label_prefix="weekly-success")

    job = _create_mock_assembly_job(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W10",
        dry_run=False,
    )

    assert job["status"] == "SUCCEEDED"
    assert job["failureCode"] is None
    assert job["summary"]["accepted"] == 20
    assert job["summary"]["listeningCount"] == 10
    assert job["summary"]["readingCount"] == 10
    assert len(job["assemblyTrace"]["selectedUnitIds"]) == 20
    assert len(set(job["assemblyTrace"]["selectedUnitIds"])) == 20
    assert len(job["assemblyTrace"]["selectedQuestionIds"]) == 20
    assert len(set(job["assemblyTrace"]["selectedQuestionIds"])) == 20

    job_id = UUID(str(job["jobId"]))
    exam_id = UUID(str(job["mockExamId"]))
    revision_id = UUID(str(job["mockExamRevisionId"]))
    with db_session_factory() as db:
        stored_job = db.get(MockAssemblyJob, job_id)
        assert stored_job is not None
        assert stored_job.status.value == "SUCCEEDED"

        exam = db.get(MockExam, exam_id)
        assert exam is not None
        assert exam.lifecycle_status == ContentLifecycleStatus.DRAFT
        assert exam.published_revision_id is None

        revision = db.get(MockExamRevision, revision_id)
        assert revision is not None
        assert revision.lifecycle_status == ContentLifecycleStatus.DRAFT

        items = db.execute(
            select(MockExamRevisionItem).where(
                MockExamRevisionItem.mock_exam_revision_id == revision_id
            )
        ).scalars().all()
        assert len(items) == 20


def test_mock_assembly_dry_run_is_deterministic_and_does_not_persist(
    client: TestClient,
    db_session_factory,
) -> None:
    _seed_weekly_assembly_pool(db_session_factory, track=Track.H2, label_prefix="weekly-dry-run")

    first = _create_mock_assembly_job(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W11",
        dry_run=True,
    )
    second = _create_mock_assembly_job(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W11",
        dry_run=True,
    )

    assert first["status"] == "SUCCEEDED"
    assert second["status"] == "SUCCEEDED"
    assert first["mockExamId"] is None
    assert second["mockExamId"] is None
    assert first["mockExamRevisionId"] is None
    assert second["mockExamRevisionId"] is None
    assert first["seed"] == second["seed"]
    assert (
        first["assemblyTrace"]["selectedQuestionIds"]
        == second["assemblyTrace"]["selectedQuestionIds"]
    )
    assert first["assemblyTrace"]["selectedUnitIds"] == second["assemblyTrace"]["selectedUnitIds"]

    with db_session_factory() as db:
        persisted_exam = db.execute(
            select(MockExam.id).where(
                MockExam.exam_type == MockExamType.WEEKLY,
                MockExam.track == Track.H2,
                MockExam.period_key == "2026W11",
            )
        ).scalar_one_or_none()
        assert persisted_exam is None


def test_monthly_assembly_creates_17_listening_and_28_reading(
    client: TestClient,
    db_session_factory,
) -> None:
    _seed_monthly_assembly_pool(db_session_factory, track=Track.H3, label_prefix="monthly-success")

    job = _create_mock_assembly_job(
        client,
        exam_type="MONTHLY",
        track="H3",
        period_key="202603",
        dry_run=False,
    )

    assert job["status"] == "SUCCEEDED"
    assert job["summary"]["accepted"] == 45
    assert job["summary"]["listeningCount"] == 17
    assert job["summary"]["readingCount"] == 28


def test_assembly_insufficient_listening_content_returns_failure_code(
    client: TestClient,
    db_session_factory,
) -> None:
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        skill=Skill.LISTENING,
        type_tag="L_GIST",
        difficulty=2,
        count=8,
        label_prefix="insufficient-listening",
    )
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        skill=Skill.READING,
        type_tag="R_MAIN_IDEA",
        difficulty=3,
        count=20,
        label_prefix="insufficient-listening",
    )

    job = _create_mock_assembly_job(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W16",
        dry_run=False,
    )
    assert job["status"] == "FAILED"
    assert job["failureCode"] == "INSUFFICIENT_LISTENING_CONTENT"
    trace = job["assemblyTrace"]
    assert trace["seed"] == "WEEKLY|2026W16|H2"
    assert "candidatePoolCounts" in trace
    assert trace["selectedUnitIds"] == []
    assert trace["selectedQuestionIds"] == []
    assert "warnings" in trace
    assert "constraintSummary" in trace


def test_assembly_rejects_legacy_type_tags_in_candidate_pool(
    client: TestClient,
    db_session_factory,
) -> None:
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        skill=Skill.LISTENING,
        type_tag="L1",
        difficulty=2,
        count=12,
        label_prefix="legacy-type-tag",
    )
    reading_rows = [
        ("R_MAIN_IDEA", 3, 3),
        ("R_DETAIL", 3, 3),
        ("R_INFERENCE", 4, 2),
        ("R_BLANK", 3, 2),
    ]
    for type_tag, difficulty, count in reading_rows:
        _seed_published_questions(
            db_session_factory,
            track=Track.H2,
            skill=Skill.READING,
            type_tag=type_tag,
            difficulty=difficulty,
            count=count,
            label_prefix="legacy-type-tag",
        )

    job = _create_mock_assembly_job(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W12",
        dry_run=False,
    )
    assert job["status"] == "FAILED"
    assert job["failureCode"] == "INSUFFICIENT_LISTENING_CONTENT"


def test_assembly_insufficient_type_diversity_returns_failure_code(
    client: TestClient,
    db_session_factory,
) -> None:
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        skill=Skill.LISTENING,
        type_tag="L_GIST",
        difficulty=2,
        count=6,
        label_prefix="insufficient-type-diversity",
    )
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        skill=Skill.LISTENING,
        type_tag="L_DETAIL",
        difficulty=3,
        count=6,
        label_prefix="insufficient-type-diversity",
    )
    reading_rows = [
        ("R_MAIN_IDEA", 3, 3),
        ("R_DETAIL", 3, 3),
        ("R_INFERENCE", 4, 2),
        ("R_BLANK", 3, 2),
    ]
    for type_tag, difficulty, count in reading_rows:
        _seed_published_questions(
            db_session_factory,
            track=Track.H2,
            skill=Skill.READING,
            type_tag=type_tag,
            difficulty=difficulty,
            count=count,
            label_prefix="insufficient-type-diversity",
        )

    job = _create_mock_assembly_job(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W13",
        dry_run=False,
    )
    assert job["status"] == "FAILED"
    assert job["failureCode"] == "INSUFFICIENT_TYPE_DIVERSITY"


def test_assembly_existing_draft_requires_force_rebuild(
    client: TestClient,
    db_session_factory,
) -> None:
    _seed_weekly_assembly_pool(db_session_factory, track=Track.H2, label_prefix="force-rebuild")

    first = _create_mock_assembly_job(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W14",
        dry_run=False,
    )
    assert first["status"] == "SUCCEEDED"

    second = _create_mock_assembly_job(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W14",
        dry_run=False,
        force_rebuild=False,
    )
    assert second["status"] == "FAILED"
    assert second["failureCode"] == "ASSEMBLY_ALREADY_EXISTS"

    first_revision_id = UUID(str(first["mockExamRevisionId"]))
    third = _create_mock_assembly_job(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W14",
        dry_run=False,
        force_rebuild=True,
    )
    assert third["status"] == "SUCCEEDED"
    assert third["mockExamRevisionId"] != first["mockExamRevisionId"]
    third_revision_id = UUID(str(third["mockExamRevisionId"]))

    with db_session_factory() as db:
        exam_id = UUID(str(first["mockExamId"]))
        revisions = db.execute(
            select(MockExamRevision).where(MockExamRevision.mock_exam_id == exam_id)
        ).scalars().all()
        assert len(revisions) == 2
        draft_count = sum(
            1 for revision in revisions if revision.lifecycle_status == ContentLifecycleStatus.DRAFT
        )
        archived_count = sum(
            1
            for revision in revisions
            if revision.lifecycle_status == ContentLifecycleStatus.ARCHIVED
        )
        assert draft_count == 1
        assert archived_count == 1

        first_revision = db.get(MockExamRevision, first_revision_id)
        assert first_revision is not None
        assert first_revision.lifecycle_status == ContentLifecycleStatus.ARCHIVED

        logs = db.execute(
            select(AuditLog).where(AuditLog.action == "mock_exam_assembly_draft_created")
        ).scalars().all()
        rebuild_logs = [
            log
            for log in logs
            if log.details.get("period_key") == "2026W14"
            and log.details.get("mock_exam_revision_id") == str(third_revision_id)
        ]
        assert len(rebuild_logs) == 1
        rebuild_details = rebuild_logs[0].details
        assert rebuild_details["force_rebuild"] is True
        assert rebuild_details["rebuild_reason"] == "force_rebuild"
        assert rebuild_details["archived_old_revision_ids"] == [str(first_revision_id)]


def test_assembly_mock_exam_creation_race_recovers_after_integrity_error(
    client: TestClient,
    db_session_factory,
    monkeypatch,
) -> None:
    _seed_weekly_assembly_pool(db_session_factory, track=Track.H2, label_prefix="race-recovery")

    with db_session_factory() as db:
        existing_exam = MockExam(
            exam_type=MockExamType.WEEKLY,
            track=Track.H2,
            period_key="2026W19",
            external_id=None,
            slug=None,
            lifecycle_status=ContentLifecycleStatus.DRAFT,
            published_revision_id=None,
        )
        db.add(existing_exam)
        db.commit()
        existing_exam_id = existing_exam.id

    original_selector = mock_assembly_service._select_mock_exam_for_update
    selector_calls = {"count": 0}

    def selector_with_forced_race(*args: object, **kwargs: object):
        selector_calls["count"] += 1
        if selector_calls["count"] == 1:
            return None
        return original_selector(*args, **kwargs)

    monkeypatch.setattr(
        mock_assembly_service,
        "_select_mock_exam_for_update",
        selector_with_forced_race,
    )

    job = _create_mock_assembly_job(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W19",
        dry_run=False,
    )
    assert selector_calls["count"] >= 2
    assert job["status"] == "SUCCEEDED"
    assert job["mockExamId"] == str(existing_exam_id)


def test_assembly_persist_failure_rolls_back_partial_draft_state(
    client: TestClient,
    db_session_factory,
    monkeypatch,
) -> None:
    _seed_weekly_assembly_pool(db_session_factory, track=Track.H2, label_prefix="persist-rollback")

    def failing_append_audit_log(*args: object, **kwargs: object) -> None:
        if kwargs.get("action") == "mock_exam_assembly_draft_created":
            raise RuntimeError("forced_persist_failure")

    monkeypatch.setattr(mock_assembly_service, "append_audit_log", failing_append_audit_log)

    job = _create_mock_assembly_job(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W17",
        dry_run=False,
    )

    assert job["status"] == "FAILED"
    assert job["failureCode"] == "REVISION_PERSIST_FAILED"
    assert job["mockExamId"] is None
    assert job["mockExamRevisionId"] is None

    with db_session_factory() as db:
        persisted_exam = db.execute(
            select(MockExam.id).where(
                MockExam.exam_type == MockExamType.WEEKLY,
                MockExam.track == Track.H2,
                MockExam.period_key == "2026W17",
            )
        ).scalar_one_or_none()
        assert persisted_exam is None

        persisted_revision_count = db.execute(
            select(func.count(MockExamRevision.id))
            .join(MockExam, MockExamRevision.mock_exam_id == MockExam.id)
            .where(
                MockExam.exam_type == MockExamType.WEEKLY,
                MockExam.track == Track.H2,
                MockExam.period_key == "2026W17",
            )
        ).scalar_one()
        assert int(persisted_revision_count) == 0

        persisted_item_count = db.execute(
            select(func.count(MockExamRevisionItem.id))
            .join(
                MockExamRevision,
                MockExamRevisionItem.mock_exam_revision_id == MockExamRevision.id,
            )
            .join(MockExam, MockExamRevision.mock_exam_id == MockExam.id)
            .where(
                MockExam.exam_type == MockExamType.WEEKLY,
                MockExam.track == Track.H2,
                MockExam.period_key == "2026W17",
            )
        ).scalar_one()
        assert int(persisted_item_count) == 0

        stored_job = db.get(MockAssemblyJob, UUID(str(job["jobId"])))
        assert stored_job is not None
        assert stored_job.status.value == "FAILED"


def test_mock_assembly_get_job_endpoint_returns_existing_job(
    client: TestClient,
    db_session_factory,
) -> None:
    _seed_weekly_assembly_pool(db_session_factory, track=Track.H2, label_prefix="job-get")
    created = _create_mock_assembly_job(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key="2026W15",
        dry_run=True,
    )

    response = client.get(
        f"/internal/mock-assembly/jobs/{created['jobId']}",
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text
    fetched = response.json()
    assert fetched["jobId"] == created["jobId"]
    assert fetched["status"] == created["status"]
