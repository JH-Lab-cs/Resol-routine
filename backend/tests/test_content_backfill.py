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
    monkeypatch.setattr(
        "app.services.content_backfill_service.settings.ai_content_provider",
        "fake",
    )
    monkeypatch.setattr(
        "app.services.content_backfill_service.settings.ai_content_model",
        "unit-test-content-model",
    )
    monkeypatch.setattr(
        "app.services.content_backfill_service.settings.ai_content_fallback_model",
        None,
    )
    monkeypatch.setattr(
        "app.services.content_backfill_service.settings.ai_content_prompt_template_version",
        "content-v1",
    )
    monkeypatch.setattr(
        "app.services.content_backfill_service.settings.ai_content_max_targets_per_run",
        12,
    )
    monkeypatch.setattr(
        "app.services.content_backfill_service.settings.ai_content_max_candidates_per_run",
        40,
    )
    monkeypatch.setattr(
        "app.services.content_backfill_service.settings.ai_content_max_estimated_cost_usd",
        5.0,
    )
    monkeypatch.setattr(
        "app.services.content_backfill_service.settings.ai_content_default_dry_run",
        True,
    )
    monkeypatch.setattr(
        "app.services.content_backfill_service.settings.ai_content_estimated_input_cost_per_million_tokens",
        0.5,
    )
    monkeypatch.setattr(
        "app.services.content_backfill_service.settings.ai_content_estimated_output_cost_per_million_tokens",
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
                "Sentence one. [1] Sentence two. [2] Sentence three. "
                "[3] Sentence four. [4]"
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
    assert report["aggregates"][0]["typeTag"] == "R_INSERTION"
    assert report["aggregates"][0]["publishableItemPerDollar"] == 4.0


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
            type_tag="L_RESPONSE",
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
            type_tag="L_RESPONSE",
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
            track=Track.H2,
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
        track=Track.H2,
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

    list_response = client.get("/public/content/units", params={"track": "H2"})
    assert list_response.status_code == 200, list_response.text
    list_body = list_response.json()
    assert any(item["revisionId"] == str(revision_id) for item in list_body["items"])

    detail_response = client.get(f"/public/content/units/{revision_id}")
    assert detail_response.status_code == 200, detail_response.text
    detail_body = detail_response.json()
    assert detail_body["revisionId"] == str(revision_id)
    assert detail_body["typeTag"] == "L_RESPONSE"

    sync_response = client.get("/public/content/sync", params={"track": "H2"})
    assert sync_response.status_code == 200, sync_response.text
    sync_body = sync_response.json()
    assert any(item["revisionId"] == str(revision_id) for item in sync_body["upserts"])


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
    metadata_extra: dict[str, object] | None = None,
) -> tuple[UUID, UUID]:
    now = datetime.now(UTC)
    is_published = lifecycle_status == ContentLifecycleStatus.PUBLISHED
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
        title=f"Title {external_id}",
        body_text=(f"Passage {external_id}" if skill == Skill.READING else None),
        transcript_text=(f"Transcript {external_id}" if skill == Skill.LISTENING else None),
        explanation_text="Explanation",
        metadata_json={
            "typeTag": type_tag,
            "difficulty": difficulty,
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
        stem="Question stem",
        choice_a="A",
        choice_b="B",
        choice_c="C",
        choice_d="D",
        choice_e="E",
        correct_answer="A",
        explanation="Question explanation",
        metadata_json={
            "typeTag": type_tag,
            "difficulty": difficulty,
            **(metadata_extra or {}),
        },
    )
    db.add(question)
    db.flush()

    if is_published:
        unit.published_revision_id = revision.id
        db.flush()

    return unit.id, revision.id
