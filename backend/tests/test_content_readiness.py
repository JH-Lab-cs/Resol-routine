from __future__ import annotations

from sqlalchemy import select

from app.models.content_enums import ContentLifecycleStatus
from app.models.enums import MockExamType, Track
from app.models.mock_exam import MockExam
from app.models.mock_exam_revision import MockExamRevision
from app.services.content_readiness_service import build_content_readiness_report
from app.services.dev_content_seed_service import seed_dev_content_and_mock_samples


def test_dev_seed_creates_daily_and_mock_readiness_baseline(db_session_factory) -> None:
    with db_session_factory() as db:
        result = seed_dev_content_and_mock_samples(db)
        db.commit()

    assert result["createdPublishedUnits"] >= 1

    with db_session_factory() as db:
        report = build_content_readiness_report(db)

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
