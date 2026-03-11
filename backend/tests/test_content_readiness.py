from __future__ import annotations

from uuid import UUID

from sqlalchemy import select

from app.models.content_enums import ContentLifecycleStatus
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import MockExamType, Track
from app.models.mock_exam import MockExam
from app.models.mock_exam_revision import MockExamRevision
from app.services.content_readiness_service import (
    build_b34_content_sync_gate,
    build_content_readiness_report,
)
from app.services.dev_content_seed_service import seed_dev_content_and_mock_samples


def test_dev_seed_creates_daily_and_mock_readiness_baseline(db_session_factory) -> None:
    with db_session_factory() as db:
        result = seed_dev_content_and_mock_samples(db)
        db.commit()

    assert result["createdPublishedUnits"] >= 1

    with db_session_factory() as db:
        report = build_content_readiness_report(db)
        assert report["policyVersion"] == "2026-03-09-b2.6.5"

        daily_tracks = report["daily"]["tracks"]
        assert daily_tracks["M3"]["readiness"] == "WARNING"
        assert daily_tracks["H1"]["readiness"] == "WARNING"
        assert daily_tracks["H2"]["readiness"] == "WARNING"
        assert daily_tracks["H3"]["readiness"] == "READY"

        mock_tracks = report["mock"]["tracks"]
        assert mock_tracks["M3"]["weekly"]["readiness"] == "NOT_READY"
        assert mock_tracks["M3"]["weekly"]["blockedByMissingContent"] is True
        assert mock_tracks["H2"]["weekly"]["readiness"] == "READY"
        assert mock_tracks["H2"]["monthly"]["readiness"] == "NOT_READY"
        assert mock_tracks["H3"]["monthly"]["readiness"] == "READY"

        vocab = report["vocab"]
        assert vocab["backendCatalogPresent"] is False
        assert vocab["serviceReadiness"] == "WARNING"
        assert vocab["tracks"]["M3"]["readiness"] == "WARNING"
        assert vocab["sourceOfTruth"] == "FRONTEND_COMPATIBILITY_SEED"

        gate = build_b34_content_sync_gate(report)
        assert gate["eligibleForB34ContentSync"] is False
        assert "daily_m3_h1_deficit_plan_required" in gate["blockers"]


def test_dev_seed_materializes_weekly_and_monthly_mock_samples(db_session_factory) -> None:
    with db_session_factory() as db:
        seed_dev_content_and_mock_samples(db)
        db.commit()

    with db_session_factory() as db:
        rows = db.execute(
            select(MockExam, MockExamRevision)
            .join(MockExamRevision, MockExamRevision.mock_exam_id == MockExam.id)
            .where(MockExamRevision.lifecycle_status == ContentLifecycleStatus.DRAFT)
            .order_by(MockExam.exam_type.asc(), MockExam.track.asc(), MockExam.period_key.asc())
        ).all()

        keys = {
            (exam.exam_type, exam.track, exam.period_key, revision.lifecycle_status)
            for exam, revision in rows
        }
        assert (
            MockExamType.WEEKLY,
            Track.H2,
            "2026W15",
            ContentLifecycleStatus.DRAFT,
        ) in keys
        assert (
            MockExamType.MONTHLY,
            Track.H3,
            "202603",
            ContentLifecycleStatus.DRAFT,
        ) in keys


def test_dev_seed_includes_backfill_draft_smoke_sample(db_session_factory) -> None:
    with db_session_factory() as db:
        result = seed_dev_content_and_mock_samples(db)
        db.commit()

    sample = result["backfillDraftSample"]
    assert sample["generationJobId"] == "11111111-1111-1111-1111-111111111111"

    with db_session_factory() as db:
        revision = db.get(ContentUnitRevision, UUID(sample["contentRevisionId"]))
        assert revision is not None
        assert revision.lifecycle_status == ContentLifecycleStatus.DRAFT
