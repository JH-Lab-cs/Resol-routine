from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

import pytest

from app.models.ai_content_generation_candidate import AIContentGenerationCandidate
from app.models.ai_content_generation_job import AIContentGenerationJob
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import (
    AIContentGenerationCandidateStatus,
    AIGenerationJobStatus,
    ContentSourcePolicy,
    ContentTypeTag,
    Skill,
    Track,
)
from app.services.content_backfill_service import (
    BackfillEvaluationFilter,
    BackfillFilter,
    ContentBackfillExecutionError,
    build_backfill_evaluation_report,
    build_content_backfill_plan,
    enqueue_content_backfill_jobs,
)
from app.services.content_readiness_service import (
    build_b34_content_sync_gate,
    build_content_readiness_report,
)
from app.services.dev_content_seed_service import seed_dev_content_and_mock_samples
from app.services.reviewer_batch_service import (
    ReviewerBatchFilter,
    batch_publish_content_revisions,
    batch_review_content_revisions,
    batch_validate_content_revisions,
)
from tools.content_readiness_audit import _build_parser as build_content_readiness_audit_parser


@pytest.fixture()
def configured_content_backfill_settings(monkeypatch: pytest.MonkeyPatch) -> None:
    settings_path = "app.services.content_backfill_service.settings."
    monkeypatch.setattr(
        f"{settings_path}ai_content_provider",
        "fake",
    )
    monkeypatch.setattr(
        f"{settings_path}ai_content_model",
        "unit-test-content-model",
    )
    monkeypatch.setattr(
        f"{settings_path}ai_content_fallback_model",
        None,
    )
    monkeypatch.setattr(
        f"{settings_path}ai_content_prompt_template_version",
        "content-v1",
    )
    monkeypatch.setattr(
        f"{settings_path}ai_content_max_targets_per_run",
        12,
    )
    monkeypatch.setattr(
        f"{settings_path}ai_content_max_candidates_per_run",
        40,
    )
    monkeypatch.setattr(
        f"{settings_path}ai_content_max_estimated_cost_usd",
        5.0,
    )
    monkeypatch.setattr(
        f"{settings_path}ai_content_default_dry_run",
        True,
    )
    monkeypatch.setattr(
        f"{settings_path}ai_content_estimated_input_cost_per_million_tokens",
        0.5,
    )
    monkeypatch.setattr(
        f"{settings_path}ai_content_estimated_output_cost_per_million_tokens",
        1.5,
    )


def test_backfill_plan_prioritizes_daily_deficits_and_keeps_dry_run_default(
    db_session_factory,
    configured_content_backfill_settings,
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
    assert preview["providerConfigured"] is True
    assert preview["apiKeyPresent"] is True
    assert preview["model"]
    assert preview["promptTemplateVersion"]
    assert preview["estimatedProviderCalls"] >= 1
    assert preview["estimatedCostUsd"] > 0
    assert all(job["targetCount"] <= 12 for job in preview["jobs"])
    assert all(job["estimatedCostUsd"] > 0 for job in preview["jobs"])
    assert all(job["originatingDeficits"] for job in preview["jobs"])


def test_backfill_plan_supports_model_override_and_evaluation_label(
    db_session_factory,
    configured_content_backfill_settings,
) -> None:
    with db_session_factory() as db:
        seed_dev_content_and_mock_samples(db)
        db.commit()

    with db_session_factory() as db:
        plan = build_content_backfill_plan(
            db,
            filters=BackfillFilter(track=Track.M3, skill=Skill.LISTENING, type_tag="L_LONG_TALK"),
            model_override="gpt-4.1-mini",
            evaluation_label="hard-typetag-ab",
        )

    preview = plan["enqueuePreview"]
    assert preview["model"] == "gpt-4.1-mini"
    assert preview["fallbackModel"] is None
    assert preview["evaluationLabel"] == "hard-typetag-ab"
    assert preview["estimatedCostUsd"] > 0


def test_backfill_plan_routes_approved_hard_typetag_to_fallback_model(
    db_session_factory,
    monkeypatch,
    configured_content_backfill_settings,
) -> None:
    monkeypatch.setattr(
        "app.services.content_backfill_service.settings.ai_content_fallback_model",
        "gpt-4.1-mini",
    )
    with db_session_factory() as db:
        seed_dev_content_and_mock_samples(db)
        db.commit()

    with db_session_factory() as db:
        plan = build_content_backfill_plan(
            db,
            filters=BackfillFilter(
                track=Track.M3,
                skill=Skill.LISTENING,
                type_tag="L_LONG_TALK",
                limit=1,
            ),
            evaluation_label="fallback-routing-check",
        )

    preview = plan["enqueuePreview"]
    assert preview["model"] == "unit-test-content-model"
    assert preview["fallbackModel"] == "gpt-4.1-mini"
    assert preview["evaluationLabel"] == "fallback-routing-check"
    assert len(preview["jobs"]) == 1
    assert preview["jobs"][0]["modelName"] == "gpt-4.1-mini"
    assert preview["jobs"][0]["fallbackTriggered"] is True
    assert preview["jobs"][0]["fallbackTypeTags"] == ["L_LONG_TALK"]


def test_content_readiness_audit_cli_uses_service_limits_by_default() -> None:
    args = build_content_readiness_audit_parser().parse_args(["--with-backfill-plan"])

    assert args.max_targets_per_run is None
    assert args.max_candidates_per_run is None


def test_backfill_enqueue_defaults_to_dry_run_without_creating_jobs(
    db_session_factory,
    configured_content_backfill_settings,
) -> None:
    with db_session_factory() as db:
        seed_dev_content_and_mock_samples(db)
        db.commit()

    with db_session_factory() as db:
        result = enqueue_content_backfill_jobs(
            db,
            filters=BackfillFilter(track=Track.M3, skill=Skill.LISTENING, limit=2),
        )

    assert result["enqueueSummary"]["executed"] is False
    assert result["enqueueSummary"]["jobCount"] == 0

    with db_session_factory() as db:
        job_count = db.query(AIContentGenerationJob).count()

    assert job_count == 0


def test_backfill_enqueue_execute_creates_ai_generation_jobs(
    db_session_factory,
    monkeypatch,
    configured_content_backfill_settings,
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
            model_override="gpt-4.1-mini",
            evaluation_label="hard-typetag-ab",
            execute=True,
        )

    assert result["enqueueSummary"]["executed"] is True
    assert result["enqueueSummary"]["jobCount"] >= 1

    with db_session_factory() as db:
        jobs = (
            db.query(AIContentGenerationJob).order_by(AIContentGenerationJob.created_at.asc()).all()
        )
        assert jobs
        assert all(job.dry_run is False for job in jobs)
        assert jobs[0].target_matrix_json
        assert jobs[0].metadata_json["source"] == "content_readiness_backfill"
        assert jobs[0].metadata_json["estimatedCostUsd"] > 0
        assert jobs[0].metadata_json["originatingDeficitPlan"]
        assert jobs[0].metadata_json["requestedModelName"] == "gpt-4.1-mini"
        assert jobs[0].metadata_json["evaluationLabel"] == "hard-typetag-ab"


def test_backfill_enqueue_execute_records_fallback_trigger_metadata(
    db_session_factory,
    monkeypatch,
    configured_content_backfill_settings,
) -> None:
    monkeypatch.setattr(
        "app.services.content_backfill_service.settings.ai_content_fallback_model",
        "gpt-4.1-mini",
    )
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
            filters=BackfillFilter(
                track=Track.H1,
                skill=Skill.READING,
                type_tag="R_INSERTION",
                limit=1,
            ),
            max_targets_per_run=1,
            max_candidates_per_run=4,
            evaluation_label="fallback-routing-check",
            execute=True,
        )

    assert result["enqueueSummary"]["executed"] is True
    assert result["enqueueSummary"]["jobCount"] == 1

    with db_session_factory() as db:
        job = db.query(AIContentGenerationJob).one()
        assert job.metadata_json["requestedModelName"] == "gpt-4.1-mini"
        assert job.metadata_json["fallbackTriggered"] is True
        assert job.metadata_json["fallbackTypeTags"] == ["R_INSERTION"]
        assert job.metadata_json["evaluationLabel"] == "fallback-routing-check"


def test_backfill_evaluation_report_summarizes_publishable_item_rates(
    db_session_factory,
    configured_content_backfill_settings,
) -> None:
    with db_session_factory() as db:
        unit_id, revision_id = _create_content_revision(
            db,
            external_id="backfill-eval-published",
            track=Track.M3,
            skill=Skill.READING,
            type_tag="R_INSERTION",
            difficulty=1,
            lifecycle_status=ContentLifecycleStatus.PUBLISHED,
            metadata_extra={
                "source": "content_readiness_backfill",
                "generationJobId": "99999999-9999-9999-9999-999999999999",
            },
        )
        job = AIContentGenerationJob(
            request_id="backfill-eval-report-job",
            status=AIGenerationJobStatus.SUCCEEDED,
            dry_run=False,
            candidate_count_per_target=1,
            target_matrix_json=[
                {
                    "track": "M3",
                    "skill": "READING",
                    "typeTag": "R_INSERTION",
                    "difficulty": 1,
                    "count": 1,
                }
            ],
            metadata_json={
                "source": "content_readiness_backfill",
                "estimatedCostUsd": 0.25,
                "evaluationLabel": "hard-typetag-ab",
                "fallbackTriggered": True,
                "fallbackTypeTags": ["R_INSERTION"],
                "originatingDeficitPlan": [
                    {
                        "track": "M3",
                        "skill": "READING",
                        "typeTag": "R_INSERTION",
                    }
                ],
            },
            provider_name="openai",
            model_name="gpt-4.1-mini",
            prompt_template_version="content-v1-reading-insertion",
            attempt_count=2,
            started_at=datetime.now(UTC),
            completed_at=datetime.now(UTC),
        )
        db.add(job)
        db.flush()
        candidate = AIContentGenerationCandidate(
            job_id=job.id,
            candidate_index=1,
            status=AIContentGenerationCandidateStatus.MATERIALIZED,
            track=Track.M3,
            skill=Skill.READING,
            type_tag=ContentTypeTag.R_INSERTION,
            difficulty=1,
            source_policy=ContentSourcePolicy.AI_ORIGINAL,
            title="Eval candidate",
            passage_text=(
                "Sentence one. [1] Sentence two. [2] Sentence three. [3] Sentence four. [4]"
            ),
            transcript_text=None,
            sentences_json=[
                {"id": "s1", "text": "Sentence one."},
                {"id": "s2", "text": "Sentence two."},
                {"id": "s3", "text": "Sentence three."},
                {"id": "s4", "text": "Sentence four."},
            ],
            turns_json=[],
            tts_plan_json={},
            question_stem="Where should the sentence be inserted?",
            choice_a="Position 1",
            choice_b="Position 2",
            choice_c="Position 3",
            choice_d="Position 4",
            choice_e="It does not fit.",
            answer_key="B",
            explanation_text="Explanation",
            evidence_sentence_ids_json=["s2", "s3"],
            why_correct_ko="정답 설명",
            why_wrong_ko_by_option_json={
                "A": "오답",
                "B": "정답 보기입니다.",
                "C": "오답",
                "D": "오답",
                "E": "오답",
            },
            review_flags_json=[],
            materialized_content_unit_id=unit_id,
            materialized_revision_id=revision_id,
        )
        db.add(candidate)
        db.commit()

    with db_session_factory() as db:
        report = build_backfill_evaluation_report(
            db,
            filters=BackfillEvaluationFilter(
                track=Track.M3,
                skill=Skill.READING,
                type_tag="R_INSERTION",
                evaluation_label="hard-typetag-ab",
            ),
        )

    assert report["runCount"] == 1
    assert report["runs"][0]["modelName"] == "gpt-4.1-mini"
    assert report["runs"][0]["validCandidateRate"] == 1.0
    assert report["runs"][0]["materializeSuccessRate"] == 1.0
    assert report["runs"][0]["publishableItemRate"] == 1.0
    assert report["runs"][0]["publishableItemPerDollar"] == 4.0
    assert report["runs"][0]["fallbackTriggered"] is True
    assert report["runs"][0]["fallbackTypeTags"] == ["R_INSERTION"]
    assert report["aggregates"][0]["typeTag"] == "R_INSERTION"
    assert report["aggregates"][0]["publishableItemPerDollar"] == 4.0
    assert report["aggregates"][0]["fallbackTriggered"] is True


def test_backfill_evaluation_report_falls_back_to_requested_model_for_failed_jobs(
    db_session_factory,
    configured_content_backfill_settings,
) -> None:
    with db_session_factory() as db:
        job = AIContentGenerationJob(
            request_id="backfill-eval-report-failed-job",
            status=AIGenerationJobStatus.FAILED,
            dry_run=False,
            candidate_count_per_target=1,
            target_matrix_json=[
                {
                    "track": "M3",
                    "skill": "LISTENING",
                    "typeTag": "L_LONG_TALK",
                    "difficulty": 1,
                    "count": 1,
                }
            ],
            metadata_json={
                "source": "content_readiness_backfill",
                "estimatedCostUsd": 0.1,
                "evaluationLabel": "hard-typetag-ab",
                "requestedModelName": "gpt-5-mini",
                "requestedPromptTemplateVersion": "content-v1",
                "originatingDeficitPlan": [
                    {
                        "track": "M3",
                        "skill": "LISTENING",
                        "typeTag": "L_LONG_TALK",
                    }
                ],
            },
            provider_name=None,
            model_name=None,
            prompt_template_version=None,
            attempt_count=1,
            started_at=datetime.now(UTC),
            completed_at=datetime.now(UTC),
        )
        db.add(job)
        db.commit()

    with db_session_factory() as db:
        report = build_backfill_evaluation_report(
            db,
            filters=BackfillEvaluationFilter(
                type_tag="L_LONG_TALK",
                evaluation_label="hard-typetag-ab",
                model_name="gpt-5-mini",
            ),
        )

    assert report["runCount"] == 1
    assert report["runs"][0]["modelName"] == "gpt-5-mini"
    assert report["runs"][0]["promptTemplateVersion"] == "content-v1"
    assert report["runs"][0]["track"] == "M3"
    assert report["runs"][0]["skill"] == "LISTENING"


def test_backfill_enqueue_rejects_unconfigured_provider_on_execute(
    db_session_factory,
    configured_content_backfill_settings,
) -> None:
    with db_session_factory() as db:
        seed_dev_content_and_mock_samples(db)
        db.commit()

    with db_session_factory() as db:
        with pytest.raises(ContentBackfillExecutionError) as exc_info:
            enqueue_content_backfill_jobs(
                db,
                filters=BackfillFilter(track=Track.M3, skill=Skill.LISTENING, limit=2),
                provider_override="disabled",
                execute=True,
            )

    assert exc_info.value.code == "PROVIDER_NOT_CONFIGURED"


def test_backfill_enqueue_rejects_budget_exceeded(
    db_session_factory,
    monkeypatch,
    configured_content_backfill_settings,
) -> None:
    monkeypatch.setattr(
        "app.services.content_backfill_service.settings.ai_content_max_estimated_cost_usd",
        0.000001,
    )
    with db_session_factory() as db:
        seed_dev_content_and_mock_samples(db)
        db.commit()

    with db_session_factory() as db:
        with pytest.raises(ContentBackfillExecutionError) as exc_info:
            enqueue_content_backfill_jobs(
                db,
                filters=BackfillFilter(track=Track.M3, skill=Skill.LISTENING, limit=2),
                execute=True,
            )

    assert exc_info.value.code == "PROVIDER_BUDGET_EXCEEDED"


def test_backfill_enqueue_rejects_missing_model_configuration(
    db_session_factory,
    monkeypatch,
    configured_content_backfill_settings,
) -> None:
    monkeypatch.setattr(
        "app.services.content_backfill_service.settings.ai_content_model",
        "not-configured",
    )
    with db_session_factory() as db:
        seed_dev_content_and_mock_samples(db)
        db.commit()

    with db_session_factory() as db:
        with pytest.raises(ContentBackfillExecutionError) as exc_info:
            enqueue_content_backfill_jobs(
                db,
                filters=BackfillFilter(track=Track.M3, skill=Skill.LISTENING, limit=2),
                execute=True,
            )

    assert exc_info.value.code == "PROVIDER_MODEL_NOT_SET"


def test_backfill_enqueue_skips_duplicate_active_deficit_signature(
    db_session_factory,
    monkeypatch,
    configured_content_backfill_settings,
) -> None:
    monkeypatch.setattr(
        "app.services.content_backfill_service.run_post_commit_ai_content_generation_tasks",
        lambda db: None,
    )
    with db_session_factory() as db:
        seed_dev_content_and_mock_samples(db)
        db.commit()

    filters = BackfillFilter(track=Track.M3, skill=Skill.LISTENING, limit=2)
    with db_session_factory() as db:
        first = enqueue_content_backfill_jobs(db, filters=filters, execute=True)
    assert first["enqueueSummary"]["jobCount"] == 1

    with db_session_factory() as db:
        second = enqueue_content_backfill_jobs(db, filters=filters, execute=True)

    assert second["enqueueSummary"]["jobCount"] == 0
    assert len(second["enqueueSummary"]["skippedExistingJobs"]) == 1


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


def test_batch_validate_review_publish_filters_backfill_source_and_generation_job_id(
    db_session_factory,
) -> None:
    backfill_job_id = UUID("22222222-2222-2222-2222-222222222222")
    other_job_id = UUID("33333333-3333-3333-3333-333333333333")

    with db_session_factory() as db:
        _seed_near_ready_daily_bank(db)
        _, tracked_revision_id = _create_content_revision(
            db,
            external_id="backfill-source-target",
            track=Track.H3,
            skill=Skill.LISTENING,
            type_tag="L_LONG_TALK",
            difficulty=4,
            lifecycle_status=ContentLifecycleStatus.DRAFT,
            metadata_extra={
                "source": "content_readiness_backfill",
                "generationJobId": str(backfill_job_id),
            },
        )
        _create_content_revision(
            db,
            external_id="backfill-source-other",
            track=Track.H3,
            skill=Skill.LISTENING,
            type_tag="L_LONG_TALK",
            difficulty=4,
            lifecycle_status=ContentLifecycleStatus.DRAFT,
            metadata_extra={
                "source": "manual_seed",
                "generationJobId": str(other_job_id),
            },
        )
        db.commit()

    filters = ReviewerBatchFilter(
        track=Track.H3,
        skill=Skill.LISTENING,
        source="content_readiness_backfill",
        generation_job_id=backfill_job_id,
        limit=1,
    )
    with db_session_factory() as db:
        before = build_content_readiness_report(db)
        validate_result = batch_validate_content_revisions(
            db,
            filters=filters,
            validator_version="ops-validator-v2",
        )
        review_result = batch_review_content_revisions(
            db,
            filters=filters,
            reviewer_identity="ops:backfill",
        )
        publish_result = batch_publish_content_revisions(
            db,
            filters=filters,
            confirm=True,
        )
        db.commit()
        after = build_content_readiness_report(db)

    assert before["daily"]["tracks"]["H3"]["readiness"] == "WARNING"
    assert validate_result["processedCount"] == 1
    assert validate_result["items"][0]["source"] == "content_readiness_backfill"
    assert validate_result["items"][0]["generationJobId"] == str(backfill_job_id)
    assert review_result["processedCount"] == 1
    assert publish_result["processedCount"] == 1
    assert publish_result["items"][0]["generationJobId"] == str(backfill_job_id)
    assert after["daily"]["tracks"]["H3"]["readiness"] == "READY"

    with db_session_factory() as db:
        tracked_revision = db.get(ContentUnitRevision, tracked_revision_id)
        assert tracked_revision is not None
        assert tracked_revision.lifecycle_status == ContentLifecycleStatus.PUBLISHED


def test_batch_publish_reports_non_publishable_backfill_draft_as_failure(
    db_session_factory,
) -> None:
    backfill_job_id = UUID("44444444-4444-4444-4444-444444444444")
    with db_session_factory() as db:
        _create_content_revision(
            db,
            external_id="backfill-non-publishable",
            track=Track.H1,
            skill=Skill.LISTENING,
            type_tag="L_RESPONSE",
            difficulty=3,
            lifecycle_status=ContentLifecycleStatus.DRAFT,
            metadata_extra={
                "source": "content_readiness_backfill",
                "generationJobId": str(backfill_job_id),
            },
        )
        db.commit()

    with db_session_factory() as db:
        result = batch_publish_content_revisions(
            db,
            filters=ReviewerBatchFilter(
                track=Track.H1,
                skill=Skill.LISTENING,
                source="content_readiness_backfill",
                generation_job_id=backfill_job_id,
                limit=1,
            ),
            confirm=True,
        )

    assert result["matchedCount"] == 1
    assert result["processedCount"] == 0
    assert result["failedCount"] == 1
    assert result["failedItems"][0]["detail"] == "revision_not_validated"
    assert result["failedItems"][0]["generationJobId"] == str(backfill_job_id)


def test_batch_publish_blocks_h2_calibration_fail_and_reports_reasons(
    db_session_factory,
) -> None:
    backfill_job_id = UUID("66666666-6666-6666-6666-666666666666")
    with db_session_factory() as db:
        _create_content_revision(
            db,
            external_id="backfill-calibration-block",
            track=Track.H2,
            skill=Skill.READING,
            type_tag="R_INSERTION",
            difficulty=3,
            lifecycle_status=ContentLifecycleStatus.DRAFT,
            metadata_extra={
                "source": "content_readiness_backfill",
                "generationJobId": str(backfill_job_id),
            },
        )
        db.commit()

    filters = ReviewerBatchFilter(
        track=Track.H2,
        skill=Skill.READING,
        source="content_readiness_backfill",
        generation_job_id=backfill_job_id,
        limit=1,
    )
    with db_session_factory() as db:
        batch_validate_content_revisions(
            db,
            filters=filters,
            validator_version="ops-validator-v4",
        )
        batch_review_content_revisions(
            db,
            filters=filters,
            reviewer_identity="ops:calibration",
        )
        result = batch_publish_content_revisions(
            db,
            filters=filters,
            confirm=True,
        )

    assert result["matchedCount"] == 1
    assert result["processedCount"] == 0
    assert result["failedCount"] == 1
    failed_item = result["failedItems"][0]
    assert failed_item["calibrationPass"] is False
    assert failed_item["calibrationScore"] is not None
    assert failed_item["calibratedLevel"] is not None
    assert failed_item["calibrationFailReasons"]
    assert failed_item["qualityGateVersion"] is not None
    assert failed_item["overrideRequired"] is False
    assert failed_item["detail"]["code"] == "content_calibration_failed"


def test_batch_publish_keeps_h1_single_warning_mode_and_surfaces_calibration_trace(
    db_session_factory,
) -> None:
    backfill_job_id = UUID("77777777-7777-7777-7777-777777777777")
    with db_session_factory() as db:
        _, revision_id = _create_content_revision(
            db,
            external_id="backfill-calibration-warning",
            track=Track.H1,
            skill=Skill.READING,
            type_tag="R_BLANK",
            difficulty=2,
            lifecycle_status=ContentLifecycleStatus.DRAFT,
            metadata_extra={
                "source": "content_readiness_backfill",
                "generationJobId": str(backfill_job_id),
            },
        )
        revision = db.get(ContentUnitRevision, revision_id)
        assert revision is not None
        revision.body_text = (
            "Students often record questions in a notebook before revising a draft. "
            "The habit helps them compare an early explanation with a later version. "
            "When they revisit the notebook, they notice where evidence remains vague. "
            "Careful revision eventually leads them to justify each claim more precisely. "
            "Over time, the notebook becomes a record of how their reasoning improves."
        )
        revision.metadata_json = {
            **revision.metadata_json,
            "typeTag": "R_BLANK",
            "difficulty": 2,
            "sentences": [
                {
                    "id": "s1",
                    "text": (
                        "Students often record questions in a notebook before revising "
                        "a draft."
                    ),
                },
                {
                    "id": "s2",
                    "text": (
                        "The habit helps them compare an early explanation with a "
                        "later version."
                    ),
                },
                {
                    "id": "s3",
                    "text": (
                        "When they revisit the notebook, they notice where evidence "
                        "remains vague."
                    ),
                },
                {
                    "id": "s4",
                    "text": (
                        "Careful revision eventually leads them to justify each claim "
                        "more precisely."
                    ),
                },
                {
                    "id": "s5",
                    "text": (
                        "Over time, the notebook becomes a record of how their "
                        "reasoning improves."
                    ),
                },
            ],
        }
        question = (
            db.query(ContentQuestion)
            .filter(ContentQuestion.content_unit_revision_id == revision_id)
            .one()
        )
        question.stem = "Which statement best completes the blank in the passage?"
        question.metadata_json = {
            **question.metadata_json,
            "typeTag": "R_BLANK",
            "difficulty": 2,
            "evidenceSentenceIds": ["s3", "s4", "s5"],
        }
        db.commit()

    filters = ReviewerBatchFilter(
        track=Track.H1,
        skill=Skill.READING,
        source="content_readiness_backfill",
        generation_job_id=backfill_job_id,
        limit=1,
    )
    with db_session_factory() as db:
        batch_validate_content_revisions(
            db,
            filters=filters,
            validator_version="ops-validator-v5",
        )
        batch_review_content_revisions(
            db,
            filters=filters,
            reviewer_identity="ops:warning-mode",
        )
        result = batch_publish_content_revisions(
            db,
            filters=filters,
            confirm=True,
        )
        db.commit()
        revision = db.get(ContentUnitRevision, revision_id)

    assert result["processedCount"] == 1
    assert result["failedCount"] == 0
    item = result["items"][0]
    assert item["calibrationPass"] is True
    assert "reading_blank_discourse_marker_sparse" in item["calibrationWarnings"]
    assert item["overrideRequired"] is False
    assert revision is not None
    assert revision.lifecycle_status == ContentLifecycleStatus.PUBLISHED
    assert revision.metadata_json["overrideRequired"] is False


def test_batch_publish_blocks_h1_when_warning_budget_is_exceeded(
    db_session_factory,
) -> None:
    backfill_job_id = UUID("88888888-8888-8888-8888-888888888888")
    with db_session_factory() as db:
        _, revision_id = _create_content_revision(
            db,
            external_id="backfill-calibration-budget-block",
            track=Track.H1,
            skill=Skill.READING,
            type_tag="R_ORDER",
            difficulty=2,
            lifecycle_status=ContentLifecycleStatus.DRAFT,
            metadata_extra={
                "source": "content_readiness_backfill",
                "generationJobId": str(backfill_job_id),
            },
        )
        revision = db.get(ContentUnitRevision, revision_id)
        assert revision is not None
        revision.body_text = (
            "Students join debate club because they want to feel better when they talk in class. "
            "They give short talks to other students and repeat the same simple "
            "points after each round. "
            "Teachers say the group answers a little more in class later. "
            "Many students come back the next year, but the passage gives only "
            "basic reasons for that change."
        )
        revision.metadata_json = {
            **revision.metadata_json,
            "typeTag": "R_ORDER",
            "difficulty": 2,
            "sentences": [
                {
                    "id": "s1",
                    "text": (
                        "Students join debate club because they want to feel better "
                        "when they talk in class."
                    ),
                },
                {
                    "id": "s2",
                    "text": (
                        "They give short talks to other students and repeat the same "
                        "simple points after each round."
                    ),
                },
                {
                    "id": "s3",
                    "text": "Teachers say the group answers a little more in class later.",
                },
                {
                    "id": "s4",
                    "text": (
                        "Many students come back the next year, but the passage gives "
                        "only basic reasons for that change."
                    ),
                },
            ],
        }
        db.commit()

    filters = ReviewerBatchFilter(
        track=Track.H1,
        skill=Skill.READING,
        source="content_readiness_backfill",
        generation_job_id=backfill_job_id,
        limit=1,
    )
    with db_session_factory() as db:
        batch_validate_content_revisions(
            db,
            filters=filters,
            validator_version="ops-validator-v6",
        )
        batch_review_content_revisions(
            db,
            filters=filters,
            reviewer_identity="ops:warning-budget",
        )
        result = batch_publish_content_revisions(
            db,
            filters=filters,
            confirm=True,
        )

    assert result["processedCount"] == 0
    assert result["failedCount"] == 1
    failed_item = result["failedItems"][0]
    assert failed_item["detail"]["code"] == "content_calibration_failed"
    assert failed_item["overrideRequired"] is True
    assert failed_item["qualityGateVersion"] is not None


def test_b34_content_sync_gate_uses_backfill_plan_to_evaluate_entry(db_session_factory) -> None:
    with db_session_factory() as db:
        seed_dev_content_and_mock_samples(db)
        db.commit()

    with db_session_factory() as db:
        report = build_content_readiness_report(db)
        plan = build_content_backfill_plan(db)
        gate = build_b34_content_sync_gate(report, backfill_plan=plan)

    assert gate["eligibleForB34ContentSync"] is True
    assert gate["status"] == "READY"
    assert gate["requirements"]["mock"]["h2WeeklyReady"] is True
    assert gate["requirements"]["mock"]["h3MonthlyReady"] is True
    assert gate["requirements"]["daily"]["m3AndH1Planned"] is True
    assert "vocab_backend_catalog_not_implemented" in gate["warnings"]


def test_batch_publish_promotes_backfill_draft_into_public_delivery_contract(
    client,
    db_session_factory,
) -> None:
    backfill_job_id = UUID("55555555-5555-5555-5555-555555555555")
    with db_session_factory() as db:
        _, revision_id = _create_content_revision(
            db,
            external_id="backfill-public-delivery",
            track=Track.H1,
            skill=Skill.LISTENING,
            type_tag="L_RESPONSE",
            difficulty=3,
            lifecycle_status=ContentLifecycleStatus.DRAFT,
            metadata_extra={
                "source": "content_readiness_backfill",
                "generationJobId": str(backfill_job_id),
            },
        )
        db.commit()

    filters = ReviewerBatchFilter(
        track=Track.H1,
        skill=Skill.LISTENING,
        source="content_readiness_backfill",
        generation_job_id=backfill_job_id,
        limit=1,
    )
    with db_session_factory() as db:
        validate_result = batch_validate_content_revisions(
            db,
            filters=filters,
            validator_version="ops-validator-v3",
        )
        review_result = batch_review_content_revisions(
            db,
            filters=filters,
            reviewer_identity="ops:delivery",
        )
        publish_result = batch_publish_content_revisions(
            db,
            filters=filters,
            confirm=True,
        )
        db.commit()

    assert validate_result["processedCount"] == 1
    assert review_result["processedCount"] == 1
    assert publish_result["processedCount"] == 1

    list_response = client.get("/public/content/units", params={"track": "H1"})
    assert list_response.status_code == 200, list_response.text
    list_body = list_response.json()
    assert any(item["revisionId"] == str(revision_id) for item in list_body["items"])

    detail_response = client.get(f"/public/content/units/{revision_id}")
    assert detail_response.status_code == 200, detail_response.text
    detail_body = detail_response.json()
    assert detail_body["revisionId"] == str(revision_id)
    assert detail_body["typeTag"] == "L_RESPONSE"

    sync_response = client.get("/public/content/sync", params={"track": "H1"})
    assert sync_response.status_code == 200, sync_response.text
    sync_body = sync_response.json()
    assert any(item["revisionId"] == str(revision_id) for item in sync_body["upserts"])


def _seed_near_ready_daily_bank(db) -> None:
    listening_types = ["L_GIST", "L_DETAIL", "L_INTENT", "L_LONG_TALK"]
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
        type_tag="L_LONG_TALK",
        difficulty=4,
        lifecycle_status=ContentLifecycleStatus.DRAFT,
    )


def _build_backfill_fixture(
    *,
    track: Track,
    skill: Skill,
    type_tag: str,
    difficulty: int,
) -> dict[str, object]:
    if skill == Skill.LISTENING:
        if type_tag == "L_RESPONSE":
            turns = [
                {
                    "speaker": "Student",
                    "text": "Do you want to check the schedule before practice?",
                },
                {"speaker": "Friend", "text": "Sure, let's look at it by the gym entrance."},
            ]
            return {
                "body_text": None,
                "transcript_text": " ".join(turn["text"] for turn in turns),
                "title": "Listening response fixture",
                "metadata_json": {
                    "typeTag": type_tag,
                    "difficulty": difficulty,
                    "turns": turns,
                    "sentences": [
                        {"id": "s1", "text": turns[0]["text"]},
                        {"id": "s2", "text": turns[1]["text"]},
                    ],
                },
                "question": {
                    "stem": "What is the most appropriate response to the last speaker?",
                    "choices": {
                        "A": "Sure, let's look at it by the gym entrance.",
                        "B": "The concert starts after the lunch break.",
                        "C": "I borrowed your notebook yesterday.",
                        "D": "The hallway looks quiet this morning.",
                        "E": "Our teacher likes the blue poster.",
                    },
                    "correct_answer": "A",
                    "explanation": (
                        "The second speaker accepts the suggestion and proposes a place."
                    ),
                    "metadata_json": {
                        "typeTag": type_tag,
                        "difficulty": difficulty,
                        "evidenceSentenceIds": ["s1", "s2"],
                        "whyCorrectKo": (
                            "제안에 동의하면서 구체적인 행동을 덧붙인 "
                            "응답이다."
                        ),
                        "whyWrongKoByOption": {
                            "B": "일정 확인 제안에 직접 반응하지 않는다.",
                            "C": "노트 언급은 대화 흐름과 무관하다.",
                            "D": "복도 상황은 맥락상 적절한 응답이 아니다.",
                            "E": "포스터 언급은 현재 상황과 관련이 없다.",
                        },
                    },
                },
            }

        if type_tag == "L_LONG_TALK":
            turns = [
                {
                    "speaker": "Host",
                    "text": (
                        "Today we will examine why public memory of a city often depends "
                        "on ordinary infrastructure rather than official monuments."
                    ),
                },
                {
                    "speaker": "Host",
                    "text": (
                        "Bridges, stations, and markets organize repeated movement, so "
                        "residents attach personal routines to structures that planners may "
                        "consider merely functional."
                    ),
                },
                {
                    "speaker": "Host",
                    "text": (
                        "When redevelopment removes those spaces, people often describe the "
                        "loss not as architectural change but as the disappearance of "
                        "familiar social timing."
                    ),
                },
                {
                    "speaker": "Guest",
                    "text": (
                        "That reaction explains why preservation debates are rarely about "
                        "nostalgia alone; they are also arguments about which daily patterns "
                        "deserve continuity."
                    ),
                },
                {
                    "speaker": "Guest",
                    "text": (
                        "In other words, infrastructure shapes civic identity because it "
                        "stabilizes how strangers repeatedly encounter one another."
                    ),
                },
            ]
            return {
                "body_text": None,
                "transcript_text": " ".join(turn["text"] for turn in turns),
                "title": "Listening long talk calibration fixture",
                "metadata_json": {
                    "typeTag": type_tag,
                    "difficulty": difficulty,
                    "turns": turns,
                    "sentences": [
                        {"id": f"s{index}", "text": turn["text"]}
                        for index, turn in enumerate(turns, start=1)
                    ],
                },
                "question": {
                    "stem": "What can be inferred from the talk?",
                    "choices": {
                        "A": (
                            "Preservation debates often concern the social routines that "
                            "infrastructure makes possible."
                        ),
                        "B": (
                            "Official monuments create stronger daily habits than "
                            "transportation systems do."
                        ),
                        "C": (
                            "Residents usually resist redevelopment only because of "
                            "tourist income."
                        ),
                        "D": (
                            "Planners rarely think about how people move through urban "
                            "space."
                        ),
                        "E": (
                            "Civic identity depends mainly on famous buildings designed by "
                            "governments."
                        ),
                    },
                    "correct_answer": "A",
                    "explanation": (
                        "The talk links preservation to the social routines that "
                        "infrastructure supports."
                    ),
                    "metadata_json": {
                        "typeTag": type_tag,
                        "difficulty": difficulty,
                        "evidenceSentenceIds": ["s4", "s5"],
                        "whyCorrectKo": (
                            "후반부에서 보존 논쟁이 일상적 동선과 사회적 "
                            "연속성에 관한 것이라고 설명한다."
                        ),
                        "whyWrongKoByOption": {
                            "B": "기념물이 더 강한 일상 습관을 만든다고 말하지 않는다.",
                            "C": "관광 수입은 핵심 이유로 제시되지 않는다.",
                            "D": "기획자가 이동을 전혀 고려하지 않는다고 단정하지 않는다.",
                            "E": "유명 건축물만이 시민 정체성을 만든다고 하지 않는다.",
                        },
                    },
                },
            }

        turns = [
            {
                "speaker": "Director",
                "text": (
                    "Before the visitors arrive, please confirm that every display panel "
                    "has a readable title card."
                ),
            },
            {
                "speaker": "Volunteer",
                "text": (
                    "I already replaced two cards, but the robotics table still needs "
                    "brighter lighting near the back wall."
                ),
            },
            {
                "speaker": "Director",
                "text": (
                    "Good, because the judges begin there and they need to follow the "
                    "explanation quickly during the first round."
                ),
            },
            {
                "speaker": "Volunteer",
                "text": (
                    "Then I will bring an extra lamp and ask Mina to guide the guests "
                    "toward the entrance line."
                ),
            },
        ]
        return {
            "body_text": None,
            "transcript_text": " ".join(turn["text"] for turn in turns),
            "title": "Listening calibration fixture",
            "metadata_json": {
                "typeTag": type_tag,
                "difficulty": difficulty,
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
                "choices": {
                    "A": "Bring more light and organize the entrance line.",
                    "B": "Cancel the exhibition before the judges enter.",
                    "C": "Move the robotics table to a different classroom.",
                    "D": "Ask the judges to skip the first display entirely.",
                    "E": "Replace every title card with handwritten notes.",
                },
                "correct_answer": "A",
                "explanation": (
                    "The final response explains the volunteer's next actions."
                ),
                "metadata_json": {
                    "typeTag": type_tag,
                    "difficulty": difficulty,
                    "evidenceSentenceIds": ["s3", "s4"],
                    "whyCorrectKo": (
                        "마지막 발화에서 추가 조명과 안내 동선 계획을 밝힌다."
                    ),
                    "whyWrongKoByOption": {
                        "B": "행사를 취소하자는 의미가 아니다.",
                        "C": "장소를 옮긴다는 말은 없다.",
                        "D": "심사 순서를 바꾸자는 내용이 아니다.",
                        "E": "제목 카드를 모두 바꾸자는 계획이 아니다.",
                    },
                },
            },
        }

    if type_tag == "R_INSERTION":
        body_text = (
            "Many students assume that academic success depends mainly on innate talent.[1] "
            "However, experienced teachers often observe that consistent revision and "
            "timely feedback are equally consequential.[2] "
            "When learners revisit earlier drafts, they begin to detect recurring "
            "weaknesses and refine imprecise reasoning.[3] "
            "Although the process can feel inefficient at first, it cultivates durable "
            "habits that extend beyond a single exam.[4]"
        )
        return {
            "body_text": body_text,
            "transcript_text": None,
            "title": "Reading insertion fixture",
            "metadata_json": {
                "typeTag": type_tag,
                "difficulty": difficulty,
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
                ],
            },
            "question": {
                "stem": "Where is the best place to insert the following sentence?",
                "choices": {
                    "A": "Before sentence [1]",
                    "B": "Between sentence [1] and [2]",
                    "C": "Between sentence [2] and [3]",
                    "D": "Between sentence [3] and [4]",
                    "E": "The sentence does not fit anywhere in the paragraph.",
                },
                "correct_answer": "B",
                "explanation": (
                    "The inserted sentence expands the contrast between talent and "
                    "revision."
                ),
                "metadata_json": {
                    "typeTag": type_tag,
                    "difficulty": difficulty,
                    "insertedSentence": (
                        "Beyond initial confidence, deliberate revision also strengthens "
                        "students' long-term judgment."
                    ),
                    "evidenceSentenceIds": ["s1", "s2"],
                    "whyCorrectKo": (
                        "첫 문장의 재능 강조 뒤에 수정 학습의 추가 효과를 "
                        "제시하는 자리가 가장 자연스럽다."
                    ),
                    "whyWrongKoByOption": {
                        "A": (
                            "지시어와 연결이 생기기 전에 나오면 흐름이 "
                            "약하다."
                        ),
                        "C": (
                            "이미 수정의 구체적 효과가 전개된 뒤라 "
                            "확장 문장으로 "
                            "늦다."
                        ),
                        "D": "결론 직전에 넣기엔 주제 확장 시점이 지나 있다.",
                        "E": "문단 주제와 분명히 연결된다.",
                    },
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
        "title": "Reading calibration fixture",
        "metadata_json": {
            "typeTag": type_tag,
            "difficulty": difficulty,
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
            "choices": {
                "A": "It helps students build reflective reasoning habits.",
                "B": "It removes the need to revise earlier drafts.",
                "C": "It proves that natural talent matters more than effort.",
                "D": "It encourages students to memorize answers more quickly.",
                "E": "It shows that unfamiliar questions should be avoided.",
            },
            "correct_answer": "A",
                "explanation": (
                    "The passage argues that feedback develops reflective and durable "
                    "thinking habits."
                ),
            "metadata_json": {
                "typeTag": type_tag,
                "difficulty": difficulty,
                "evidenceSentenceIds": ["s6", "s7"],
                "whyCorrectKo": (
                    "마지막 두 문장이 피드백의 핵심 목적을 요약한다."
                ),
                "whyWrongKoByOption": {
                    "B": "초안을 다시 보는 과정이 중요하다고 설명한다.",
                    "C": "타고난 재능만을 강조하는 글이 아니다.",
                    "D": "암기 속도 향상은 핵심 목적이 아니다.",
                    "E": "낯선 문제를 피하라는 내용이 아니다.",
                },
            },
        },
    }


def _create_content_revision(
    db,
    *,
    external_id: str,
    track: Track,
    skill: Skill,
    type_tag: str,
    difficulty: int,
    lifecycle_status: ContentLifecycleStatus,
    metadata_extra: dict[str, object] | None = None,
) -> tuple[UUID, UUID]:
    now = datetime.now(UTC)
    is_published = lifecycle_status == ContentLifecycleStatus.PUBLISHED
    fixture = _build_backfill_fixture(
        track=track,
        skill=skill,
        type_tag=type_tag,
        difficulty=difficulty,
    )
    unit = ContentUnit(
        external_id=external_id,
        slug=external_id,
        skill=skill,
        track=track,
        lifecycle_status=(
            ContentLifecycleStatus.PUBLISHED if is_published else ContentLifecycleStatus.DRAFT
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
        title=fixture["title"],
        body_text=fixture["body_text"],
        transcript_text=fixture["transcript_text"],
        explanation_text=fixture["question"]["explanation"],
        metadata_json={
            **fixture["metadata_json"],
            **(metadata_extra or {}),
        },
        lifecycle_status=lifecycle_status,
        published_at=(now if lifecycle_status == ContentLifecycleStatus.PUBLISHED else None),
    )
    db.add(revision)
    db.flush()

    question = ContentQuestion(
        content_unit_revision_id=revision.id,
        question_code=f"q-{external_id}"[:64],
        order_index=1,
        stem=fixture["question"]["stem"],
        choice_a=fixture["question"]["choices"]["A"],
        choice_b=fixture["question"]["choices"]["B"],
        choice_c=fixture["question"]["choices"]["C"],
        choice_d=fixture["question"]["choices"]["D"],
        choice_e=fixture["question"]["choices"]["E"],
        correct_answer=fixture["question"]["correct_answer"],
        explanation=fixture["question"]["explanation"],
        metadata_json={
            **fixture["question"]["metadata_json"],
            **(metadata_extra or {}),
        },
    )
    db.add(question)
    db.flush()

    if is_published:
        unit.published_revision_id = revision.id
        db.flush()

    return unit.id, revision.id
