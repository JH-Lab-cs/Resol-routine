from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.core.policies import AI_JOB_MAX_ATTEMPTS, R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS
from app.core.timekeys import period_key
from app.models.ai_generation_job import AIGenerationJob
from app.models.audit_log import AuditLog
from app.models.content_enums import ContentLifecycleStatus
from app.models.content_question import ContentQuestion
from app.models.content_unit import ContentUnit
from app.models.content_unit_revision import ContentUnitRevision
from app.models.enums import (
    AIGenerationJobStatus,
    Skill,
    SubscriptionFeatureCode,
    SubscriptionPlanStatus,
    Track,
    UserRole,
    UserSubscriptionStatus,
)
from app.models.mock_exam_revision import MockExamRevision
from app.models.parent_child_link import ParentChildLink
from app.models.subscription_plan import SubscriptionPlan
from app.models.subscription_plan_feature import SubscriptionPlanFeature
from app.models.user import User
from app.models.user_subscription import UserSubscription
from app.services import ai_artifact_service
import app.services.ai_job_service as ai_job_service
from app.services.ai_job_service import run_mock_exam_draft_generation_job
from app.services.ai_provider import (
    AIProviderError,
    DeterministicMockExamProvider,
    ProviderGenerationResult,
    ProviderStructuredItem,
    ProviderStructuredOutput,
)
import app.workers.tasks as worker_tasks

INTERNAL_API_KEY = "unit-test-internal-api-key-value"


class FakeAIArtifactStore:
    def __init__(self) -> None:
        self._counter = 0
        self._objects: dict[str, str] = {}

    def put_json(self, *, kind: str, job_id: UUID, payload: dict[str, object]) -> str:
        return self.put_text(
            kind=kind,
            job_id=job_id,
            body=json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
            content_type="application/json",
        )

    def put_text(self, *, kind: str, job_id: UUID, body: str, content_type: str = "text/plain") -> str:  # noqa: ARG002
        self._counter += 1
        normalized_kind = kind.replace(" ", "-")
        object_key = f"ai-artifacts/test/{job_id}/{normalized_kind}-{self._counter}.json"
        self._objects[object_key] = body
        return object_key

    def get_text(self, *, object_key: str) -> str:
        if object_key not in self._objects:
            raise ai_artifact_service.ArtifactStoreError(
                code="artifact_object_not_found",
                message="Artifact object does not exist.",
            )
        return self._objects[object_key]

    def get_json(self, *, object_key: str) -> dict[str, object]:
        text_payload = self.get_text(object_key=object_key)
        decoded = json.loads(text_payload)
        if not isinstance(decoded, dict):
            raise ai_artifact_service.ArtifactStoreError(
                code="artifact_object_invalid_json",
                message="Artifact payload must be a JSON object.",
            )
        return decoded

    def generate_download_url(self, *, object_key: str, expires_in_seconds: int) -> str:
        if object_key not in self._objects:
            raise ai_artifact_service.ArtifactStoreError(
                code="artifact_object_not_found",
                message="Artifact object does not exist.",
            )
        return f"https://fake-ai-r2.local/download/{object_key}?ttl={expires_in_seconds}"

    def delete_object(self, *, object_key: str) -> None:
        if object_key not in self._objects:
            raise ai_artifact_service.ArtifactStoreError(
                code="artifact_object_not_found",
                message="Artifact object does not exist.",
            )
        del self._objects[object_key]


@pytest.fixture()
def fake_ai_artifact_store(monkeypatch: pytest.MonkeyPatch) -> FakeAIArtifactStore:
    store = FakeAIArtifactStore()
    monkeypatch.setattr(ai_job_service, "get_ai_artifact_store", lambda: store)
    monkeypatch.setattr(ai_artifact_service, "get_ai_artifact_store", lambda: store)
    return store


@pytest.fixture()
def captured_ai_enqueues(monkeypatch: pytest.MonkeyPatch) -> list[UUID]:
    captured: list[UUID] = []

    def fake_trigger(*, job_id: UUID) -> None:
        captured.append(job_id)

    monkeypatch.setattr(worker_tasks, "trigger_ai_generation_job", fake_trigger)
    return captured


def _internal_headers(api_key: str = INTERNAL_API_KEY) -> dict[str, str]:
    return {"X-Internal-Api-Key": api_key}


def _student_headers(access_token: str) -> dict[str, str]:
    return {"authorization": f"Bearer {access_token}"}


def _register_student(
    client: TestClient,
    *,
    email: str,
    password: str = "SecurePass123!",
    device_id: str = "device-1",
) -> dict[str, object]:
    response = client.post(
        "/auth/register/student",
        json={"email": email, "password": password, "device_id": device_id},
    )
    assert response.status_code == 201, response.text
    return response.json()


def _grant_student_entitlements(
    db_session_factory,
    *,
    student_id: UUID,
    feature_codes: set[SubscriptionFeatureCode],
) -> None:
    seed = uuid4().hex[:8]
    with db_session_factory() as db:
        parent = User(
            email=f"ai-entitled-parent-{seed}@example.com",
            password_hash="hashed-password",
            role=UserRole.PARENT,
        )
        db.add(parent)
        db.flush()

        db.add(ParentChildLink(parent_id=parent.id, child_id=student_id))

        plan = SubscriptionPlan(
            plan_code=f"ai-plan-{seed}",
            display_name=f"AI Plan {seed}",
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
    period_key_value: str,
    external_id: str,
) -> dict[str, object]:
    response = client.post(
        "/internal/mock-exams",
        json={
            "examType": exam_type,
            "track": track,
            "periodKey": period_key_value,
            "externalId": external_id,
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _create_ai_job(
    client: TestClient,
    *,
    mock_exam_id: str,
    request_id: str,
    candidate_limit: int = 300,
) -> dict[str, object]:
    response = client.post(
        "/internal/ai/jobs/mock-exams",
        json={
            "requestId": request_id,
            "mockExamId": mock_exam_id,
            "notes": "Generate a deterministic draft revision.",
            "generatorVersion": "ai-generator-v1",
            "candidateLimit": candidate_limit,
            "metadata": {"source": "pytest"},
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _run_job_once(db_session_factory, *, job_id: str) -> ai_job_service.AIJobExecutionResult:
    with db_session_factory() as db:
        result = run_mock_exam_draft_generation_job(db, job_id=UUID(job_id))
        db.commit()
    return result


def _seed_published_questions(
    db_session_factory,
    *,
    track: Track,
    listening_count: int,
    reading_count: int,
) -> list[dict[str, object]]:
    seed = uuid4().hex[:8]
    references: list[dict[str, object]] = []

    with db_session_factory() as db:
        now = datetime.now(UTC)
        total = listening_count + reading_count

        for index in range(total):
            skill = Skill.LISTENING if index < listening_count else Skill.READING
            unit = ContentUnit(
                external_id=f"ai-unit-{seed}-{index}",
                slug=f"ai-unit-{seed}-{index}",
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
                asset_id=None,
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
                    "contentQuestionId": str(question.id),
                    "contentUnitRevisionId": str(revision.id),
                    "skill": skill.value,
                }
            )

        db.commit()

    return references


def _seed_unpublished_reading_question(db_session_factory, *, track: Track) -> dict[str, str]:
    seed = uuid4().hex[:8]

    with db_session_factory() as db:
        unit = ContentUnit(
            external_id=f"unpublished-ai-unit-{seed}",
            slug=f"unpublished-ai-unit-{seed}",
            skill=Skill.READING,
            track=track,
            lifecycle_status=ContentLifecycleStatus.DRAFT,
        )
        db.add(unit)
        db.flush()

        revision = ContentUnitRevision(
            content_unit_id=unit.id,
            revision_no=1,
            revision_code=f"unpub-r1-{seed}",
            generator_version="seed-generator",
            validator_version=None,
            validated_at=None,
            reviewer_identity=None,
            reviewed_at=None,
            title="Unpublished title",
            body_text="Unpublished body",
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
            stem="Unpublished stem",
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
        "contentQuestionId": str(question.id),
        "contentUnitRevisionId": str(revision.id),
    }


def test_internal_ai_api_key_missing_and_invalid_rejected(client: TestClient) -> None:
    payload = {
        "requestId": "ai-job-key-test",
        "mockExamId": str(uuid4()),
        "generatorVersion": "ai-generator-v1",
    }

    missing = client.post("/internal/ai/jobs/mock-exams", json=payload)
    assert missing.status_code == 401
    assert missing.json()["detail"] == "missing_internal_api_key"

    invalid = client.post(
        "/internal/ai/jobs/mock-exams",
        json=payload,
        headers=_internal_headers("invalid-key"),
    )
    assert invalid.status_code == 403
    assert invalid.json()["detail"] == "invalid_internal_api_key"


def test_create_job_and_duplicate_request_id_returns_existing(
    client: TestClient,
    db_session_factory,
    captured_ai_enqueues: list[UUID],
) -> None:
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key_value="2026W12",
        external_id="ai-weekly-h2-2026w12",
    )

    first = _create_ai_job(
        client,
        mock_exam_id=str(exam["id"]),
        request_id="req-ai-job-001",
    )
    second = _create_ai_job(
        client,
        mock_exam_id=str(exam["id"]),
        request_id="req-ai-job-001",
    )

    assert first["id"] == second["id"]
    assert first["jobType"] == "MOCK_EXAM_REVISION_DRAFT_GENERATION"
    assert first["status"] == "QUEUED"
    assert captured_ai_enqueues == [UUID(str(first["id"]))]


def test_worker_success_creates_draft_revision_with_traceability(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    captured_ai_enqueues: list[UUID],
) -> None:
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key_value="2026W13",
        external_id="ai-weekly-h2-2026w13",
    )

    job = _create_ai_job(client, mock_exam_id=str(exam["id"]), request_id="req-ai-job-success")
    assert captured_ai_enqueues == [UUID(str(job["id"]))]

    result = _run_job_once(db_session_factory, job_id=str(job["id"]))
    assert result.status == AIGenerationJobStatus.SUCCEEDED
    assert result.produced_mock_exam_revision_id is not None

    with db_session_factory() as db:
        stored_job = db.get(AIGenerationJob, UUID(str(job["id"])))
        assert stored_job is not None
        assert stored_job.status == AIGenerationJobStatus.SUCCEEDED
        assert stored_job.produced_mock_exam_revision_id is not None
        assert stored_job.provider_name == "fake"
        assert stored_job.model_name == "unit-test-model"
        assert stored_job.prompt_template_version == "v1"
        assert stored_job.candidate_snapshot_object_key is not None
        assert stored_job.input_artifact_object_key is not None
        assert stored_job.output_artifact_object_key is not None

        produced_revision = db.get(MockExamRevision, stored_job.produced_mock_exam_revision_id)
        assert produced_revision is not None
        assert produced_revision.lifecycle_status == ContentLifecycleStatus.DRAFT

    assert len(fake_ai_artifact_store._objects) >= 3


def test_duplicate_worker_execution_does_not_create_duplicate_revision(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    captured_ai_enqueues: list[UUID],
) -> None:
    _ = fake_ai_artifact_store
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key_value="2026W14",
        external_id="ai-weekly-h2-2026w14",
    )

    job = _create_ai_job(client, mock_exam_id=str(exam["id"]), request_id="req-ai-job-dup-worker")
    first_run = _run_job_once(db_session_factory, job_id=str(job["id"]))
    second_run = _run_job_once(db_session_factory, job_id=str(job["id"]))

    assert first_run.status == AIGenerationJobStatus.SUCCEEDED
    assert second_run.status == AIGenerationJobStatus.SUCCEEDED
    assert first_run.produced_mock_exam_revision_id == second_run.produced_mock_exam_revision_id

    with db_session_factory() as db:
        revision_count = db.execute(
            select(func.count()).select_from(MockExamRevision).where(MockExamRevision.mock_exam_id == UUID(str(exam["id"])))
        ).scalar_one()
    assert revision_count == 1


def test_retry_after_transient_failure_succeeds(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    captured_ai_enqueues: list[UUID],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _ = fake_ai_artifact_store
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key_value="2026W15",
        external_id="ai-weekly-h2-2026w15",
    )
    job = _create_ai_job(client, mock_exam_id=str(exam["id"]), request_id="req-ai-job-retry")

    class FlakyProvider:
        def __init__(self) -> None:
            self._calls = 0
            self._fallback = DeterministicMockExamProvider(model_name="unit-test-model", prompt_template_version="v1")

        def generate_structured_output(
            self,
            *,
            context,
        ) -> ProviderGenerationResult:
            self._calls += 1
            if self._calls == 1:
                raise AIProviderError(
                    code="provider_timeout",
                    message="Transient timeout",
                    transient=True,
                )
            return self._fallback.generate_structured_output(context=context)

    provider = FlakyProvider()
    monkeypatch.setattr(ai_job_service, "build_mock_exam_generation_provider", lambda: provider)

    first_result = _run_job_once(db_session_factory, job_id=str(job["id"]))
    assert first_result.status == AIGenerationJobStatus.FAILED
    assert first_result.error_code == "provider_timeout"

    retry_response = client.post(
        f"/internal/ai/jobs/{job['id']}/retry",
        headers=_internal_headers(),
    )
    assert retry_response.status_code == 200, retry_response.text
    retry_body = retry_response.json()
    assert retry_body["status"] == "QUEUED"
    assert captured_ai_enqueues == [UUID(str(job["id"])), UUID(str(job["id"]))]

    second_result = _run_job_once(db_session_factory, job_id=str(job["id"]))
    assert second_result.status == AIGenerationJobStatus.SUCCEEDED
    assert second_result.produced_mock_exam_revision_id is not None

    with db_session_factory() as db:
        stored_job = db.get(AIGenerationJob, UUID(str(job["id"])))
        assert stored_job is not None
        assert stored_job.attempt_count == 2


def test_invalid_ai_output_duplicate_order_fails_job(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _ = fake_ai_artifact_store
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key_value="2026W16",
        external_id="ai-weekly-h2-2026w16",
    )
    job = _create_ai_job(client, mock_exam_id=str(exam["id"]), request_id="req-ai-job-bad-order")

    class DuplicateOrderProvider:
        def generate_structured_output(self, *, context) -> ProviderGenerationResult:
            first = context.candidate_questions[0]
            second = context.candidate_questions[1]
            return ProviderGenerationResult(
                provider_name="fake",
                model_name="unit-test-model",
                prompt_template_version="v1",
                raw_prompt="{}",
                raw_response="{}",
                structured_output=ProviderStructuredOutput(
                    title="Invalid output",
                    instructions="Invalid output",
                    items=[
                        ProviderStructuredItem(order_index=1, content_question_id=first.content_question_id),
                        ProviderStructuredItem(order_index=1, content_question_id=second.content_question_id),
                    ],
                ),
            )

    monkeypatch.setattr(ai_job_service, "build_mock_exam_generation_provider", lambda: DuplicateOrderProvider())

    result = _run_job_once(db_session_factory, job_id=str(job["id"]))
    assert result.status == AIGenerationJobStatus.FAILED
    assert result.error_code == "invalid_order_sequence"


def test_invalid_ai_output_skill_count_mismatch_fails_job(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _ = fake_ai_artifact_store
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=11,
        reading_count=10,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key_value="2026W17",
        external_id="ai-weekly-h2-2026w17",
    )
    job = _create_ai_job(client, mock_exam_id=str(exam["id"]), request_id="req-ai-job-skill-mismatch")

    class SkillMismatchProvider:
        def generate_structured_output(self, *, context) -> ProviderGenerationResult:
            selected = context.candidate_questions[:19]
            return ProviderGenerationResult(
                provider_name="fake",
                model_name="unit-test-model",
                prompt_template_version="v1",
                raw_prompt="{}",
                raw_response="{}",
                structured_output=ProviderStructuredOutput(
                    title="Skill mismatch output",
                    instructions="Skill mismatch output",
                    items=[
                        ProviderStructuredItem(order_index=index + 1, content_question_id=item.content_question_id)
                        for index, item in enumerate(selected)
                    ],
                ),
            )

    monkeypatch.setattr(ai_job_service, "build_mock_exam_generation_provider", lambda: SkillMismatchProvider())

    result = _run_job_once(db_session_factory, job_id=str(job["id"]))
    assert result.status == AIGenerationJobStatus.FAILED
    assert result.error_code == "mock_exam_skill_count_mismatch"


def test_unpublished_reference_in_snapshot_fails_job(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
) -> None:
    references = _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )
    unpublished_reference = _seed_unpublished_reading_question(db_session_factory, track=Track.H2)

    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key_value="2026W18",
        external_id="ai-weekly-h2-2026w18",
    )
    job = _create_ai_job(client, mock_exam_id=str(exam["id"]), request_id="req-ai-job-unpublished")

    injected_candidates = []
    reading_replaced = False
    for reference in references:
        if reference["skill"] == Skill.READING.value and not reading_replaced:
            injected_candidates.append(
                {
                    "contentQuestionId": unpublished_reference["contentQuestionId"],
                    "contentUnitRevisionId": unpublished_reference["contentUnitRevisionId"],
                    "questionCode": "UNPUBLISHED-Q",
                    "skill": Skill.READING.value,
                    "stem": "Unpublished stem",
                    "hasAsset": False,
                    "unitTitle": "Unpublished unit",
                }
            )
            reading_replaced = True
            continue

        injected_candidates.append(
            {
                "contentQuestionId": reference["contentQuestionId"],
                "contentUnitRevisionId": reference["contentUnitRevisionId"],
                "questionCode": str(reference["contentQuestionId"]),
                "skill": reference["skill"],
                "stem": "Seed stem",
                "hasAsset": False,
                "unitTitle": "Seed unit",
            }
        )

    with db_session_factory() as db:
        job_row = db.get(AIGenerationJob, UUID(str(job["id"])))
        assert job_row is not None
        snapshot_key = fake_ai_artifact_store.put_json(
            kind="candidate-snapshot",
            job_id=job_row.id,
            payload={
                "candidateQuestions": injected_candidates,
            },
        )
        job_row.candidate_snapshot_object_key = snapshot_key
        db.commit()

    result = _run_job_once(db_session_factory, job_id=str(job["id"]))
    assert result.status == AIGenerationJobStatus.FAILED
    assert result.error_code == "content_revision_not_published"


def test_generated_draft_not_visible_to_student_current_exam(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
) -> None:
    _ = fake_ai_artifact_store
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )

    current_week_key = period_key(datetime.now(UTC), "WEEKLY")
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key_value=current_week_key,
        external_id="ai-weekly-h2-current",
    )
    job = _create_ai_job(client, mock_exam_id=str(exam["id"]), request_id="req-ai-job-draft-visibility")

    _run_job_once(db_session_factory, job_id=str(job["id"]))

    student = _register_student(client, email="ai-draft-hidden@example.com")
    _grant_student_entitlements(
        db_session_factory,
        student_id=UUID(str(student["user"]["id"])),
        feature_codes={SubscriptionFeatureCode.WEEKLY_MOCK_EXAMS},
    )
    response = client.get(
        "/mock-exams/weekly/current",
        params={"track": "H2"},
        headers=_student_headers(str(student["access_token"])),
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "current_mock_exam_not_found"


def test_generated_draft_publish_then_student_delivery_success(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
) -> None:
    _ = fake_ai_artifact_store
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )

    current_week_key = period_key(datetime.now(UTC), "WEEKLY")
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key_value=current_week_key,
        external_id="ai-weekly-h2-current-publish",
    )
    job = _create_ai_job(client, mock_exam_id=str(exam["id"]), request_id="req-ai-job-publish")

    result = _run_job_once(db_session_factory, job_id=str(job["id"]))
    assert result.produced_mock_exam_revision_id is not None
    revision_id = str(result.produced_mock_exam_revision_id)

    validate_response = client.post(
        f"/internal/mock-exams/{exam['id']}/revisions/{revision_id}/validate",
        json={"validatorVersion": "mock-validator-v1"},
        headers=_internal_headers(),
    )
    assert validate_response.status_code == 200, validate_response.text

    review_response = client.post(
        f"/internal/mock-exams/{exam['id']}/revisions/{revision_id}/review",
        json={"reviewerIdentity": "reviewer-jane"},
        headers=_internal_headers(),
    )
    assert review_response.status_code == 200, review_response.text

    publish_response = client.post(
        f"/internal/mock-exams/{exam['id']}/publish",
        json={"revisionId": revision_id},
        headers=_internal_headers(),
    )
    assert publish_response.status_code == 200, publish_response.text

    student = _register_student(client, email="ai-generated-published@example.com")
    _grant_student_entitlements(
        db_session_factory,
        student_id=UUID(str(student["user"]["id"])),
        feature_codes={SubscriptionFeatureCode.WEEKLY_MOCK_EXAMS},
    )
    current_response = client.get(
        "/mock-exams/weekly/current",
        params={"track": "H2"},
        headers=_student_headers(str(student["access_token"])),
    )
    assert current_response.status_code == 200, current_response.text
    current_body = current_response.json()
    assert current_body["mockExamRevisionId"] == revision_id

    session_start = client.post(
        f"/mock-exams/{revision_id}/sessions",
        headers=_student_headers(str(student["access_token"])),
    )
    assert session_start.status_code == 200, session_start.text
    session_body = session_start.json()
    assert isinstance(session_body["mockSessionId"], int)

    detail_response = client.get(
        f"/mock-exam-sessions/{session_body['mockSessionId']}",
        headers=_student_headers(str(student["access_token"])),
    )
    assert detail_response.status_code == 200, detail_response.text
    detail_body = detail_response.json()
    assert len(detail_body["items"]) == 20
    first_item = detail_body["items"][0]
    assert isinstance(first_item["questionId"], str)
    assert "correct_answer" not in first_item
    assert "explanation" not in first_item


def test_ai_job_artifact_download_url_ttl_contract(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
) -> None:
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key_value="2026W19",
        external_id="ai-weekly-h2-2026w19",
    )

    job = _create_ai_job(client, mock_exam_id=str(exam["id"]), request_id="req-ai-job-artifact")
    _run_job_once(db_session_factory, job_id=str(job["id"]))

    response = client.get(
        f"/internal/ai/jobs/{job['id']}/artifacts/input/download-url",
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["artifactKind"] == "input"
    assert body["expiresInSeconds"] == R2_DOWNLOAD_SIGNED_URL_TTL_SECONDS
    assert "ttl=300" in body["downloadUrl"]


def test_hidden_unicode_request_id_rejected(
    client: TestClient,
    db_session_factory,
) -> None:
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key_value="2026W20",
        external_id="ai-weekly-h2-2026w20",
    )

    response = client.post(
        "/internal/ai/jobs/mock-exams",
        json={
            "requestId": "req\u200bid-hidden",
            "mockExamId": str(exam["id"]),
            "generatorVersion": "ai-generator-v1",
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 422
    error_messages = [error["msg"] for error in response.json()["detail"]]
    assert any("invalid_hidden_unicode" in message for message in error_messages)


def test_transient_failures_transition_to_dead_letter(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _ = fake_ai_artifact_store
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key_value="2026W21",
        external_id="ai-weekly-h2-2026w21",
    )
    job = _create_ai_job(client, mock_exam_id=str(exam["id"]), request_id="req-ai-job-dead-letter")

    class AlwaysTransientFailureProvider:
        def generate_structured_output(self, *, context) -> ProviderGenerationResult:  # noqa: ARG002
            raise AIProviderError(
                code="provider_timeout",
                message="Transient timeout",
                transient=True,
            )

    monkeypatch.setattr(ai_job_service, "build_mock_exam_generation_provider", lambda: AlwaysTransientFailureProvider())

    for _ in range(AI_JOB_MAX_ATTEMPTS):
        _run_job_once(db_session_factory, job_id=str(job["id"]))
        with db_session_factory() as db:
            stored = db.get(AIGenerationJob, UUID(str(job["id"])))
            assert stored is not None
            if stored.status == AIGenerationJobStatus.DEAD_LETTER:
                break
            assert stored.status == AIGenerationJobStatus.FAILED
            assert stored.next_retry_at is not None
            stored.next_retry_at = datetime.now(UTC) - timedelta(seconds=1)
            db.commit()

    with db_session_factory() as db:
        stored = db.get(AIGenerationJob, UUID(str(job["id"])))
        assert stored is not None
        assert stored.status == AIGenerationJobStatus.DEAD_LETTER
        assert stored.dead_lettered_at is not None
        assert stored.next_retry_at is None
        assert stored.last_error_transient is True
        assert stored.attempt_count == AI_JOB_MAX_ATTEMPTS


def test_ai_artifact_purge_removes_old_objects_and_audits(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
) -> None:
    _seed_published_questions(
        db_session_factory,
        track=Track.H2,
        listening_count=10,
        reading_count=10,
    )
    exam = _create_mock_exam(
        client,
        exam_type="WEEKLY",
        track="H2",
        period_key_value="2026W22",
        external_id="ai-weekly-h2-2026w22",
    )
    job = _create_ai_job(client, mock_exam_id=str(exam["id"]), request_id="req-ai-job-purge")
    _run_job_once(db_session_factory, job_id=str(job["id"]))

    with db_session_factory() as db:
        stored = db.get(AIGenerationJob, UUID(str(job["id"])))
        assert stored is not None
        stored.completed_at = datetime.now(UTC) - timedelta(days=45)
        db.commit()

    response = client.post(
        "/internal/ai/jobs/artifacts/purge",
        json={"retentionDays": 30},
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["purgedJobCount"] == 1
    assert body["purgedObjectCount"] >= 3

    with db_session_factory() as db:
        stored = db.get(AIGenerationJob, UUID(str(job["id"])))
        assert stored is not None
        assert stored.input_artifact_object_key is None
        assert stored.output_artifact_object_key is None
        assert stored.candidate_snapshot_object_key is None
        audit_rows = db.execute(
            select(AuditLog).where(AuditLog.action == "ai_job_artifacts_purged")
        ).scalars().all()
        assert audit_rows
