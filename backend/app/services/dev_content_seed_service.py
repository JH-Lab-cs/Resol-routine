from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import MockExamType, Skill, Track
from app.models.mock_exam import MockExam
from app.models.mock_exam_revision import MockExamRevision
from app.schemas.mock_assembly import MockAssemblyJobCreateRequest
from app.services.content_sync_service import append_content_upsert_event
from app.services.mock_assembly_service import create_mock_assembly_job

DEV_SEED_GENERATOR_VERSION = "dev-seed-generator-v1"
DEV_SEED_VALIDATOR_VERSION = "dev-seed-validator-v1"
DEV_SEED_REVIEWER_IDENTITY = "dev-seed-reviewer"


@dataclass(frozen=True, slots=True)
class DevSeedRow:
    track: Track
    skill: Skill
    type_tag: str
    difficulty: int
    count: int
    label_prefix: str


def seed_dev_content_and_mock_samples(db: Session) -> dict[str, object]:
    created_units = 0
    skipped_units = 0

    for row in _dev_seed_rows():
        created_count, skipped_count = _seed_published_questions(
            db,
            track=row.track,
            skill=row.skill,
            type_tag=row.type_tag,
            difficulty=row.difficulty,
            count=row.count,
            label_prefix=row.label_prefix,
        )
        created_units += created_count
        skipped_units += skipped_count

    weekly_job = _ensure_mock_sample(
        db,
        exam_type=MockExamType.WEEKLY,
        track=Track.H2,
        period_key="2026W15",
    )
    monthly_job = _ensure_mock_sample(
        db,
        exam_type=MockExamType.MONTHLY,
        track=Track.H3,
        period_key="202603",
    )

    return {
        "createdPublishedUnits": created_units,
        "skippedPublishedUnits": skipped_units,
        "weeklySample": weekly_job,
        "monthlySample": monthly_job,
    }


def _seed_published_questions(
    db: Session,
    *,
    track: Track,
    skill: Skill,
    type_tag: str,
    difficulty: int,
    count: int,
    label_prefix: str,
) -> tuple[int, int]:
    now = datetime.now(UTC)
    created = 0
    skipped = 0

    for index in range(count):
        external_id = f"{label_prefix}-unit-{skill.value}-{type_tag}-{index}"
        existing_unit_id = db.execute(
            select(ContentUnit.id).where(ContentUnit.external_id == external_id)
        ).scalar_one_or_none()
        if existing_unit_id is not None:
            skipped += 1
            continue

        unit = ContentUnit(
            external_id=external_id,
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
            revision_code=_build_revision_code(
                track=track,
                skill=skill,
                type_tag=type_tag,
                difficulty=difficulty,
                index=index,
            ),
            generator_version=DEV_SEED_GENERATOR_VERSION,
            validator_version=DEV_SEED_VALIDATOR_VERSION,
            validated_at=now,
            reviewer_identity=DEV_SEED_REVIEWER_IDENTITY,
            reviewed_at=now,
            title=f"{label_prefix} title {index}",
            body_text=(
                f"{label_prefix} reading body text {index}"
                if skill == Skill.READING
                else None
            ),
            transcript_text=(
                f"{label_prefix} listening transcript text {index}"
                if skill == Skill.LISTENING
                else None
            ),
            explanation_text="Dev seed explanation text",
            metadata_json={},
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
            stem=f"Dev seed stem {label_prefix} {index}",
            choice_a="Option A",
            choice_b="Option B",
            choice_c="Option C",
            choice_d="Option D",
            choice_e="Option E",
            correct_answer="A",
            explanation="Dev seed explanation",
            metadata_json={
                "typeTag": type_tag,
                "difficulty": difficulty,
                "sourcePolicy": "AI_ORIGINAL",
            },
        )
        db.add(question)
        db.flush()

        append_content_upsert_event(
            db,
            unit=unit,
            revision=revision,
            published_at=now,
        )
        created += 1

    return created, skipped


def _build_revision_code(
    *,
    track: Track,
    skill: Skill,
    type_tag: str,
    difficulty: int,
    index: int,
) -> str:
    # Keep revision_code under the persisted 32-char limit while staying deterministic.
    type_compact = type_tag.replace("_", "")[:10]
    return f"dev-{track.value}-{skill.value[0]}-{type_compact}-d{difficulty}-{index}"


def _ensure_mock_sample(
    db: Session,
    *,
    exam_type: MockExamType,
    track: Track,
    period_key: str,
) -> dict[str, object]:
    existing_row = db.execute(
        select(MockExam, MockExamRevision)
        .join(MockExamRevision, MockExamRevision.mock_exam_id == MockExam.id)
        .where(
            MockExam.exam_type == exam_type,
            MockExam.track == track,
            MockExam.period_key == period_key,
            MockExamRevision.lifecycle_status == ContentLifecycleStatus.DRAFT,
        )
        .order_by(MockExamRevision.revision_no.desc(), MockExamRevision.id.desc())
    ).first()
    if existing_row is not None:
        exam, revision = existing_row
        return {
            "status": "EXISTING",
            "mockExamId": str(exam.id),
            "mockExamRevisionId": str(revision.id),
            "examType": exam_type.value,
            "track": track.value,
            "periodKey": period_key,
        }

    payload = MockAssemblyJobCreateRequest.model_validate(
        {
            "examType": exam_type.value,
            "track": track.value,
            "periodKey": period_key,
            "dryRun": False,
            "forceRebuild": False,
        }
    )
    response = create_mock_assembly_job(db, payload=payload)
    if response.produced_mock_exam_id is None or response.produced_mock_exam_revision_id is None:
        raise RuntimeError(
            "Failed to seed "
            f"{exam_type.value} mock sample for {track.value}: "
            f"{response.failure_code}"
        )
    return {
        "status": response.status.value,
        "mockExamId": str(response.produced_mock_exam_id),
        "mockExamRevisionId": str(response.produced_mock_exam_revision_id),
        "examType": exam_type.value,
        "track": track.value,
        "periodKey": period_key,
    }


def _dev_seed_rows() -> tuple[DevSeedRow, ...]:
    return (
        DevSeedRow(Track.M3, Skill.LISTENING, "L_GIST", 1, 2, "dev-seed-m3-daily"),
        DevSeedRow(Track.M3, Skill.LISTENING, "L_DETAIL", 2, 2, "dev-seed-m3-daily"),
        DevSeedRow(Track.M3, Skill.LISTENING, "L_INTENT", 2, 2, "dev-seed-m3-daily"),
        DevSeedRow(Track.M3, Skill.READING, "R_MAIN_IDEA", 1, 2, "dev-seed-m3-daily"),
        DevSeedRow(Track.M3, Skill.READING, "R_DETAIL", 2, 2, "dev-seed-m3-daily"),
        DevSeedRow(Track.M3, Skill.READING, "R_INFERENCE", 2, 2, "dev-seed-m3-daily"),
        DevSeedRow(Track.H1, Skill.LISTENING, "L_GIST", 2, 2, "dev-seed-h1-daily"),
        DevSeedRow(Track.H1, Skill.LISTENING, "L_DETAIL", 2, 2, "dev-seed-h1-daily"),
        DevSeedRow(Track.H1, Skill.LISTENING, "L_INTENT", 3, 2, "dev-seed-h1-daily"),
        DevSeedRow(Track.H1, Skill.LISTENING, "L_RESPONSE", 3, 2, "dev-seed-h1-daily"),
        DevSeedRow(Track.H1, Skill.READING, "R_MAIN_IDEA", 2, 2, "dev-seed-h1-daily"),
        DevSeedRow(Track.H1, Skill.READING, "R_DETAIL", 2, 2, "dev-seed-h1-daily"),
        DevSeedRow(Track.H1, Skill.READING, "R_INFERENCE", 3, 2, "dev-seed-h1-daily"),
        DevSeedRow(Track.H1, Skill.READING, "R_VOCAB", 3, 2, "dev-seed-h1-daily"),
        DevSeedRow(Track.H2, Skill.LISTENING, "L_GIST", 3, 4, "dev-seed-h2-weekly"),
        DevSeedRow(Track.H2, Skill.LISTENING, "L_DETAIL", 3, 4, "dev-seed-h2-weekly"),
        DevSeedRow(Track.H2, Skill.LISTENING, "L_INTENT", 2, 4, "dev-seed-h2-weekly"),
        DevSeedRow(Track.H2, Skill.READING, "R_MAIN_IDEA", 3, 3, "dev-seed-h2-weekly"),
        DevSeedRow(Track.H2, Skill.READING, "R_DETAIL", 3, 3, "dev-seed-h2-weekly"),
        DevSeedRow(Track.H2, Skill.READING, "R_INFERENCE", 4, 2, "dev-seed-h2-weekly"),
        DevSeedRow(Track.H2, Skill.READING, "R_BLANK", 3, 2, "dev-seed-h2-weekly"),
        DevSeedRow(Track.H3, Skill.LISTENING, "L_GIST", 3, 6, "dev-seed-h3-monthly"),
        DevSeedRow(Track.H3, Skill.LISTENING, "L_DETAIL", 4, 5, "dev-seed-h3-monthly"),
        DevSeedRow(Track.H3, Skill.LISTENING, "L_INTENT", 3, 5, "dev-seed-h3-monthly"),
        DevSeedRow(Track.H3, Skill.LISTENING, "L_LONG_TALK", 4, 5, "dev-seed-h3-monthly"),
        DevSeedRow(Track.H3, Skill.READING, "R_MAIN_IDEA", 4, 6, "dev-seed-h3-monthly"),
        DevSeedRow(Track.H3, Skill.READING, "R_DETAIL", 3, 6, "dev-seed-h3-monthly"),
        DevSeedRow(Track.H3, Skill.READING, "R_INFERENCE", 4, 6, "dev-seed-h3-monthly"),
        DevSeedRow(Track.H3, Skill.READING, "R_BLANK", 4, 6, "dev-seed-h3-monthly"),
        DevSeedRow(Track.H3, Skill.READING, "R_ORDER", 3, 6, "dev-seed-h3-monthly"),
        DevSeedRow(Track.H3, Skill.READING, "R_INSERTION", 4, 6, "dev-seed-h3-monthly"),
    )
