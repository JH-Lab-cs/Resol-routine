from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from app.models.ai_content_generation_job import AIContentGenerationJob
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import Skill, Track
from app.services.content_backfill_service import (
    BackfillFilter,
    build_content_backfill_plan,
    enqueue_content_backfill_jobs,
)
from app.services.content_readiness_service import build_content_readiness_report
from app.services.dev_content_seed_service import seed_dev_content_and_mock_samples
from app.services.reviewer_batch_service import (
    ReviewerBatchFilter,
    batch_publish_content_revisions,
    batch_review_content_revisions,
    batch_validate_content_revisions,
)


def test_backfill_plan_prioritizes_daily_deficits_and_keeps_dry_run_default(
    db_session_factory,
) -> None:
    with db_session_factory() as db:
        seed_dev_content_and_mock_samples(db)
        db.commit()

    with db_session_factory() as db:
        plan = build_content_backfill_plan(db)

    assert plan["dryRunDefault"] is True
    assert plan["readiness"]["policyVersion"] == plan["policyVersion"]
    assert plan["contentDeficits"]
    priorities = [row["priority"] for row in plan["contentDeficits"]]
    assert priorities == sorted(priorities)
    assert plan["contentDeficits"][0]["reason"] == "DAILY_READINESS_DEFICIT"
    assert any(row["typeTag"] == "L_RESPONSE" for row in plan["contentDeficits"])
    assert plan["vocabDeficits"]
    assert plan["vocabDeficits"][0]["reason"] == "VOCAB_BANDING_DEFICIT"
    preview = plan["enqueuePreview"]
    assert preview["dryRunDefault"] is True
    assert preview["provider"]
    assert preview["model"]
    assert preview["promptTemplateVersion"]
    assert all(job["targetCount"] <= 12 for job in preview["jobs"])


def test_backfill_enqueue_execute_creates_ai_generation_jobs(
    db_session_factory,
    monkeypatch,
) -> None:
    monkeypatch.setattr(
        "app.services.content_backfill_service.run_post_commit_ai_content_generation_tasks",
        lambda db: None,
    )
    with db_session_factory() as db:
        seed_dev_content_and_mock_samples(db)
        db.commit()

    with db_session_factory() as db:
        result = enqueue_content_backfill_jobs(
            db,
            filters=BackfillFilter(track=Track.M3, skill=Skill.LISTENING, limit=3),
            max_targets_per_run=2,
            max_candidates_per_run=6,
            execute=True,
        )

    assert result["enqueueSummary"]["executed"] is True
    assert result["enqueueSummary"]["jobCount"] >= 1

    with db_session_factory() as db:
        jobs = (
            db.query(AIContentGenerationJob)
            .order_by(AIContentGenerationJob.created_at.asc())
            .all()
        )
        assert jobs
        assert all(job.dry_run is False for job in jobs)
        assert jobs[0].target_matrix_json
        assert jobs[0].metadata_json["source"] == "content_readiness_backfill"


def test_batch_validate_review_publish_improves_daily_readiness(db_session_factory) -> None:
    with db_session_factory() as db:
        _seed_near_ready_daily_bank(db)
        db.commit()

    with db_session_factory() as db:
        before = build_content_readiness_report(db)
        assert before["daily"]["tracks"]["H3"]["readiness"] == "WARNING"

        filters = ReviewerBatchFilter(track=Track.H3, skill=Skill.LISTENING, limit=1)
        validate_result = batch_validate_content_revisions(
            db,
            filters=filters,
            validator_version="ops-validator-v1",
        )
        review_result = batch_review_content_revisions(
            db,
            filters=filters,
            reviewer_identity="ops:jihun",
        )
        publish_result = batch_publish_content_revisions(
            db,
            filters=filters,
            confirm=True,
        )
        db.commit()

        after = build_content_readiness_report(db)

    assert validate_result["processedCount"] == 1
    assert review_result["processedCount"] == 1
    assert publish_result["processedCount"] == 1
    assert after["daily"]["tracks"]["H3"]["readiness"] == "READY"


def _seed_near_ready_daily_bank(db) -> None:
    listening_types = ["L_GIST", "L_DETAIL", "L_INTENT", "L_RESPONSE"]
    reading_types = [
        "R_MAIN_IDEA",
        "R_DETAIL",
        "R_INFERENCE",
        "R_BLANK",
        "R_ORDER",
        "R_INSERTION",
    ]
    for index in range(20):
        _create_content_revision(
            db,
            external_id=f"ready-h3-listening-{index}",
            track=Track.H3,
            skill=Skill.LISTENING,
            type_tag=listening_types[index % len(listening_types)],
            difficulty=3 if index % 3 == 0 else 4,
            lifecycle_status=ContentLifecycleStatus.PUBLISHED,
        )
    for index in range(21):
        _create_content_revision(
            db,
            external_id=f"ready-h3-reading-{index}",
            track=Track.H3,
            skill=Skill.READING,
            type_tag=reading_types[index % len(reading_types)],
            difficulty=3 if index % 3 == 0 else 4,
            lifecycle_status=ContentLifecycleStatus.PUBLISHED,
        )
    _create_content_revision(
        db,
        external_id="ready-h3-listening-draft",
        track=Track.H3,
        skill=Skill.LISTENING,
        type_tag="L_RESPONSE",
        difficulty=4,
        lifecycle_status=ContentLifecycleStatus.DRAFT,
    )


def _create_content_revision(
    db,
    *,
    external_id: str,
    track: Track,
    skill: Skill,
    type_tag: str,
    difficulty: int,
    lifecycle_status: ContentLifecycleStatus,
) -> tuple[UUID, UUID]:
    now = datetime.now(UTC)
    is_published = lifecycle_status == ContentLifecycleStatus.PUBLISHED
    unit = ContentUnit(
        external_id=external_id,
        slug=external_id,
        skill=skill,
        track=track,
        lifecycle_status=(
            ContentLifecycleStatus.PUBLISHED
            if is_published
            else ContentLifecycleStatus.DRAFT
        ),
    )
    db.add(unit)
    db.flush()

    revision = ContentUnitRevision(
        content_unit_id=unit.id,
        revision_no=1,
        revision_code=f"rev-{external_id}"[:32],
        generator_version="test-generator-v1",
        validator_version="seed-validator-v1" if is_published else None,
        validated_at=now if is_published else None,
        reviewer_identity="seed-reviewer" if is_published else None,
        reviewed_at=now if is_published else None,
        title=f"Title {external_id}",
        body_text=(f"Passage {external_id}" if skill == Skill.READING else None),
        transcript_text=(f"Transcript {external_id}" if skill == Skill.LISTENING else None),
        explanation_text="Explanation",
        metadata_json={"typeTag": type_tag, "difficulty": difficulty},
        lifecycle_status=lifecycle_status,
        published_at=(now if lifecycle_status == ContentLifecycleStatus.PUBLISHED else None),
    )
    db.add(revision)
    db.flush()

    question = ContentQuestion(
        content_unit_revision_id=revision.id,
        question_code=f"q-{external_id}"[:64],
        order_index=1,
        stem="Question stem",
        choice_a="A",
        choice_b="B",
        choice_c="C",
        choice_d="D",
        choice_e="E",
        correct_answer="A",
        explanation="Question explanation",
        metadata_json={"typeTag": type_tag, "difficulty": difficulty},
    )
    db.add(question)
    db.flush()

    if is_published:
        unit.published_revision_id = revision.id
        db.flush()

    return unit.id, revision.id
