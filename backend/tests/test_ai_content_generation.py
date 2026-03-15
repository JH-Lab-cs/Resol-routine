from __future__ import annotations

import json
from dataclasses import replace
from uuid import UUID

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

import app.services.ai_content_generation_service as ai_content_generation_service
import app.workers.tasks as worker_tasks
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
from app.services import ai_artifact_service
from app.services.ai_content_generation_service import run_ai_content_generation_job
from app.services.ai_content_provider import ContentGenerationResult, GeneratedContentCandidate
from app.services.ai_provider import AIProviderError
from app.services.l_response_generation_service import (
    L_RESPONSE_COMPILER_VERSION,
    L_RESPONSE_GENERATION_MODE,
)
from app.services.type_specific_generation_quality_service import (
    L_SITUATION_CONTEXTUAL_COMPILER_VERSION,
    L_SITUATION_CONTEXTUAL_GENERATION_MODE,
    L_SITUATION_CONTEXTUAL_GENERATION_PROFILE,
)

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

    def put_text(
        self, *, kind: str, job_id: UUID, body: str, content_type: str = "text/plain"
    ) -> str:
        self._counter += 1
        normalized_kind = kind.replace(" ", "-")
        object_key = f"ai-artifacts/test/{job_id}/{normalized_kind}-{self._counter}.json"
        self._objects[object_key] = body
        return object_key

    def put_text_with_object_key(
        self, *, object_key: str, body: str, content_type: str = "text/plain"
    ) -> str:
        self._objects[object_key] = body
        return object_key

    def put_json_with_object_key(self, *, object_key: str, payload: dict[str, object]) -> str:
        self._objects[object_key] = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        return object_key

    def get_text(self, *, object_key: str) -> str:
        if object_key not in self._objects:
            raise ai_artifact_service.ArtifactStoreError(
                code="artifact_object_not_found",
                message="Artifact object does not exist.",
            )
        return self._objects[object_key]

    def get_json(self, *, object_key: str) -> dict[str, object]:
        payload = json.loads(self.get_text(object_key=object_key))
        if not isinstance(payload, dict):
            raise ai_artifact_service.ArtifactStoreError(
                code="artifact_object_invalid_json",
                message="Artifact payload must be a JSON object.",
            )
        return payload

    def generate_download_url(self, *, object_key: str, expires_in_seconds: int) -> str:
        return f"https://fake-ai-r2.local/download/{object_key}?ttl={expires_in_seconds}"

    def delete_object(self, *, object_key: str) -> None:
        self._objects.pop(object_key, None)


class FailingArtifactStore(FakeAIArtifactStore):
    def put_text(
        self, *, kind: str, job_id: UUID, body: str, content_type: str = "text/plain"
    ) -> str:
        raise ai_artifact_service.ArtifactStoreError(
            code="artifact_write_failed",
            message="failed to upload artifact",
        )

    def put_text_with_object_key(
        self, *, object_key: str, body: str, content_type: str = "text/plain"
    ) -> str:
        raise ai_artifact_service.ArtifactStoreError(
            code="artifact_write_failed",
            message="failed to upload artifact",
        )


class StaticProvider:
    def __init__(self, candidates: list[GeneratedContentCandidate]) -> None:
        self._candidates = candidates

    def generate_candidates(self, *, context) -> ContentGenerationResult:
        return ContentGenerationResult(
            provider_name="fake",
            model_name="ai-content-test-model",
            prompt_template_version="v-test",
            raw_prompt=json.dumps({"requestId": context.request_id}, ensure_ascii=False),
            raw_response=json.dumps({"candidates": ["generated"]}, ensure_ascii=False),
            candidates=self._candidates,
        )


@pytest.fixture()
def fake_ai_artifact_store(monkeypatch: pytest.MonkeyPatch) -> FakeAIArtifactStore:
    store = FakeAIArtifactStore()
    monkeypatch.setattr(ai_content_generation_service, "get_ai_artifact_store", lambda: store)
    monkeypatch.setattr(ai_artifact_service, "get_ai_artifact_store", lambda: store)
    return store


@pytest.fixture()
def captured_ai_content_enqueues(monkeypatch: pytest.MonkeyPatch) -> list[UUID]:
    captured: list[UUID] = []

    def fake_trigger(*, job_id: UUID) -> None:
        captured.append(job_id)

    monkeypatch.setattr(worker_tasks, "trigger_ai_content_generation_job", fake_trigger)
    return captured


def _patch_provider_builder(
    monkeypatch: pytest.MonkeyPatch,
    provider: object,
) -> None:
    def _builder(
        *, provider_override=None, model_override=None, prompt_template_version_override=None
    ):
        del provider_override, model_override, prompt_template_version_override
        return provider

    monkeypatch.setattr(
        ai_content_generation_service,
        "build_ai_content_generation_provider",
        _builder,
    )


def _internal_headers(api_key: str = INTERNAL_API_KEY) -> dict[str, str]:
    return {"X-Internal-Api-Key": api_key}


def _create_job(
    client: TestClient,
    *,
    request_id: str,
    matrix: list[dict[str, object]],
    candidate_count_per_target: int = 1,
    dry_run: bool = False,
) -> dict[str, object]:
    response = client.post(
        "/internal/ai/content-generation/jobs",
        json={
            "requestId": request_id,
            "targetMatrix": matrix,
            "candidateCountPerTarget": candidate_count_per_target,
            "dryRun": dry_run,
            "metadata": {"source": "pytest"},
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _run_job_once(db_session_factory, *, job_id: str):
    with db_session_factory() as db:
        result = run_ai_content_generation_job(db, job_id=UUID(job_id))
        db.commit()
    return result


def _valid_candidate(
    *,
    skill: Skill,
    type_tag: ContentTypeTag,
    track: Track = Track.H2,
    difficulty: int = 3,
) -> GeneratedContentCandidate:
    options = {
        "A": "Correct answer with clear evidence",
        "B": "Distractor based on unrelated detail",
        "C": "Distractor with wrong inference",
        "D": "Distractor from partial reading",
        "E": "Distractor with vocabulary trap",
    }
    why_wrong = {
        "A": "정답 보기입니다.",
        "B": "핵심 근거와 연결되지 않습니다.",
        "C": "추론 방향이 지문과 다릅니다.",
        "D": "부분 정보만 보고 판단했습니다.",
        "E": "어휘 유사성에만 의존했습니다.",
    }

    if skill == Skill.READING:
        passage = (
            "Sentence one provides context. "
            "Sentence two gives evidence. "
            "Sentence three confirms conclusion."
        )
        stem = "Which option best matches the passage?"
        if type_tag == ContentTypeTag.R_BLANK:
            passage = "Sentence one provides context. [BLANK] Sentence three confirms conclusion."
            stem = "Which option best fills the [BLANK]?"
        elif type_tag == ContentTypeTag.R_INSERTION:
            passage = (
                "Sentence one provides context. [1] Sentence two gives evidence. "
                "[2] Sentence three confirms conclusion. [3] Sentence four adds contrast. [4]"
            )
            stem = "Where should the sentence be inserted?"
        elif type_tag == ContentTypeTag.R_VOCAB:
            stem = "What is the meaning of the underlined word in context?"

        return GeneratedContentCandidate(
            track=track,
            skill=skill,
            type_tag=type_tag,
            difficulty=difficulty,
            source_policy=ContentSourcePolicy.AI_ORIGINAL,
            title="Generated reading unit",
            passage=passage,
            transcript=None,
            turns=[],
            sentences=[
                {"id": "s1", "text": "Sentence one provides context."},
                {"id": "s2", "text": "Sentence two gives evidence."},
                {"id": "s3", "text": "Sentence three confirms conclusion."},
            ],
            tts_plan={},
            stem=stem,
            options=options,
            answer_key="A",
            explanation=(
                "Option A is correct because sentence s2 directly supports "
                "the claim and sentence s3 confirms it."
            ),
            evidence_sentence_ids=["s2", "s3"],
            why_correct_ko="핵심 근거 문장이 정답 선택지의 주장과 직접 연결됩니다.",
            why_wrong_ko_by_option=why_wrong,
            vocab_notes_ko="evidence, conclusion 표현을 확인하세요.",
            structure_notes_ko="근거 문장(s2)과 결론 문장(s3)을 연결해 판단하세요.",
        )

    transcript = (
        "A: Could you summarize the key point?\nB: We must verify evidence before deciding."
    )
    turns = [
        {"speaker": "A", "text": "Could you summarize the key point?"},
        {"speaker": "B", "text": "We must verify evidence before deciding."},
    ]
    sentences = [
        {"id": "s1", "text": "Could you summarize the key point?"},
        {"id": "s2", "text": "We must verify evidence before deciding."},
    ]
    if type_tag == ContentTypeTag.L_LONG_TALK:
        turns = [
            {"speaker": "A", "text": "Welcome to the school radio update."},
            {"speaker": "B", "text": "Today we will explain the field-trip schedule."},
            {"speaker": "A", "text": "Students should gather by 8 a.m. at the main gate."},
            {"speaker": "B", "text": "Please bring water and a notebook for observations."},
        ]
        transcript = "\n".join(f"{turn['speaker']}: {turn['text']}" for turn in turns)
        sentences = [
            {"id": "s1", "text": "Welcome to the school radio update."},
            {"id": "s2", "text": "Today we will explain the field-trip schedule."},
            {"id": "s3", "text": "Students should gather by 8 a.m. at the main gate."},
            {"id": "s4", "text": "Please bring water and a notebook for observations."},
        ]

    return GeneratedContentCandidate(
        track=track,
        skill=skill,
        type_tag=type_tag,
        difficulty=difficulty,
        source_policy=ContentSourcePolicy.AI_ORIGINAL,
        title="Generated listening unit",
        passage=None,
        transcript=transcript,
        turns=turns,
        sentences=sentences,
        tts_plan={"voice": "en-US-neutral", "pace": "normal"},
        stem="What is the best interpretation of the dialogue?",
        options=options,
        answer_key="A",
        explanation=(
            "Option A is correct because the response explicitly prioritizes evidence verification."
        ),
        evidence_sentence_ids=["s2"],
        why_correct_ko="응답 화자가 근거 확인을 우선한다고 명시하므로 정답이 됩니다.",
        why_wrong_ko_by_option=why_wrong,
        vocab_notes_ko="verify evidence 표현을 확인하세요.",
        structure_notes_ko="질문-응답 구조에서 응답 문장을 중심으로 판단하세요.",
    )


def test_internal_api_key_missing_and_invalid_rejected(client: TestClient) -> None:
    payload = {
        "requestId": "ai-content-key-test",
        "targetMatrix": [
            {
                "track": "H2",
                "skill": "READING",
                "typeTag": "R_MAIN_IDEA",
                "difficulty": 3,
                "count": 1,
            }
        ],
    }

    missing = client.post("/internal/ai/content-generation/jobs", json=payload)
    assert missing.status_code == 401
    assert missing.json()["detail"] == "missing_internal_api_key"

    invalid = client.post(
        "/internal/ai/content-generation/jobs",
        json=payload,
        headers=_internal_headers("invalid-key"),
    )
    assert invalid.status_code == 403
    assert invalid.json()["detail"] == "invalid_internal_api_key"


def test_job_create_rejects_legacy_numeric_type_tag_on_new_write_path(client: TestClient) -> None:
    response = client.post(
        "/internal/ai/content-generation/jobs",
        json={
            "requestId": "ai-content-legacy-tag-reject",
            "targetMatrix": [
                {
                    "track": "H2",
                    "skill": "READING",
                    "typeTag": "R1",
                    "difficulty": 3,
                    "count": 1,
                }
            ],
        },
        headers=_internal_headers(),
    )

    assert response.status_code == 422
    detail = response.json()["detail"]
    assert isinstance(detail, list)
    assert any(error["loc"] == ["body", "targetMatrix", 0, "typeTag"] for error in detail)


def test_job_create_rejects_skill_and_type_tag_mismatch(client: TestClient) -> None:
    response = client.post(
        "/internal/ai/content-generation/jobs",
        json={
            "requestId": "ai-content-mismatch-tag-reject",
            "targetMatrix": [
                {
                    "track": "H2",
                    "skill": "LISTENING",
                    "typeTag": "R_MAIN_IDEA",
                    "difficulty": 3,
                    "count": 1,
                }
            ],
        },
        headers=_internal_headers(),
    )

    assert response.status_code == 422
    detail = response.json()["detail"]
    assert isinstance(detail, list)
    assert any("skill_type_tag_mismatch" in str(error.get("msg", "")) for error in detail)


def test_job_create_duplicate_request_returns_existing_and_enqueues_once(
    client: TestClient,
    captured_ai_content_enqueues: list[UUID],
) -> None:
    matrix = [
        {"track": "H2", "skill": "READING", "typeTag": "R_MAIN_IDEA", "difficulty": 3, "count": 2},
    ]
    first = _create_job(client, request_id="content-job-dup-1", matrix=matrix)
    second = _create_job(client, request_id="content-job-dup-1", matrix=matrix)

    assert first["id"] == second["id"]
    assert captured_ai_content_enqueues == [UUID(first["id"])]


def test_target_matrix_count_drives_candidate_attempts(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
) -> None:
    matrix = [
        {"track": "H2", "skill": "READING", "typeTag": "R_MAIN_IDEA", "difficulty": 3, "count": 2},
        {"track": "H2", "skill": "LISTENING", "typeTag": "L_DETAIL", "difficulty": 2, "count": 1},
    ]
    job = _create_job(
        client,
        request_id="content-job-count-1",
        matrix=matrix,
        candidate_count_per_target=2,
    )

    result = _run_job_once(db_session_factory, job_id=job["id"])
    assert result.status == AIGenerationJobStatus.SUCCEEDED

    with db_session_factory() as db:
        count = (
            db.execute(
                select(AIContentGenerationCandidate).where(
                    AIContentGenerationCandidate.job_id == UUID(job["id"])
                )
            )
            .scalars()
            .all()
        )
        assert len(count) == 6


def test_provider_not_configured_failure(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    matrix = [
        {"track": "H2", "skill": "READING", "typeTag": "R_MAIN_IDEA", "difficulty": 3, "count": 1}
    ]
    job = _create_job(client, request_id="content-job-provider-missing", matrix=matrix)

    def raise_not_configured(
        *, provider_override=None, model_override=None, prompt_template_version_override=None
    ):
        raise AIProviderError(
            code="PROVIDER_NOT_CONFIGURED",
            message="provider missing",
            transient=False,
        )

    monkeypatch.setattr(
        ai_content_generation_service, "build_ai_content_generation_provider", raise_not_configured
    )

    result = _run_job_once(db_session_factory, job_id=job["id"])
    assert result.status == AIGenerationJobStatus.FAILED

    with db_session_factory() as db:
        stored = db.get(AIContentGenerationJob, UUID(job["id"]))
        assert stored is not None
        assert stored.last_error_code == "PROVIDER_NOT_CONFIGURED"


def test_malformed_provider_response_rejected(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    matrix = [
        {"track": "H2", "skill": "READING", "typeTag": "R_MAIN_IDEA", "difficulty": 3, "count": 1}
    ]
    job = _create_job(client, request_id="content-job-bad-response", matrix=matrix)

    def raise_bad_response(
        *, provider_override=None, model_override=None, prompt_template_version_override=None
    ):
        raise AIProviderError(
            code="PROVIDER_BAD_RESPONSE",
            message="bad response",
            transient=False,
        )

    monkeypatch.setattr(
        ai_content_generation_service, "build_ai_content_generation_provider", raise_bad_response
    )

    result = _run_job_once(db_session_factory, job_id=job["id"])
    assert result.status == AIGenerationJobStatus.FAILED

    with db_session_factory() as db:
        stored = db.get(AIContentGenerationJob, UUID(job["id"]))
        assert stored is not None
        assert stored.last_error_code == "PROVIDER_BAD_RESPONSE"


def test_hidden_unicode_invalid_options_and_invalid_evidence_are_rejected(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    bad = _valid_candidate(skill=Skill.READING, type_tag=ContentTypeTag.R_MAIN_IDEA)
    bad = replace(
        bad,
        stem="Hidden\u200b stem",
        options={
            "A": "Same text",
            "B": "Same text",
            "C": "Option C",
            "D": "Option D",
            "F": "Wrong key",
        },
        evidence_sentence_ids=["missing-sentence"],
    )

    _patch_provider_builder(monkeypatch, StaticProvider([bad]))

    matrix = [
        {"track": "H2", "skill": "READING", "typeTag": "R_MAIN_IDEA", "difficulty": 3, "count": 1}
    ]
    job = _create_job(client, request_id="content-job-invalid-candidate", matrix=matrix)

    result = _run_job_once(db_session_factory, job_id=job["id"])
    assert result.status == AIGenerationJobStatus.SUCCEEDED

    listed = client.get(
        f"/internal/ai/content-generation/jobs/{job['id']}/candidates",
        headers=_internal_headers(),
    )
    assert listed.status_code == 200, listed.text
    body = listed.json()
    assert len(body["items"]) == 1
    assert body["items"][0]["status"] == AIContentGenerationCandidateStatus.INVALID.value
    assert body["items"][0]["failureCode"] == "OUTPUT_OPTION_DUPLICATE"


def test_skill_type_tag_and_difficulty_mismatch_rejected(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    bad = _valid_candidate(skill=Skill.READING, type_tag=ContentTypeTag.R_MAIN_IDEA)
    bad = replace(
        bad,
        skill=Skill.LISTENING,
        type_tag=ContentTypeTag.R_MAIN_IDEA,
        difficulty=7,
        transcript=None,
        turns=[],
        tts_plan={},
    )

    _patch_provider_builder(monkeypatch, StaticProvider([bad]))

    matrix = [
        {"track": "H2", "skill": "LISTENING", "typeTag": "L_DETAIL", "difficulty": 3, "count": 1}
    ]
    job = _create_job(client, request_id="content-job-mismatch", matrix=matrix)
    result = _run_job_once(db_session_factory, job_id=job["id"])
    assert result.status == AIGenerationJobStatus.SUCCEEDED

    listed = client.get(
        f"/internal/ai/content-generation/jobs/{job['id']}/candidates",
        headers=_internal_headers(),
    )
    assert listed.status_code == 200, listed.text
    assert listed.json()["items"][0]["status"] == AIContentGenerationCandidateStatus.INVALID.value


def test_hard_typetag_listening_alignment_errors_map_to_sentence_mismatch(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    bad = _valid_candidate(
        skill=Skill.LISTENING,
        type_tag=ContentTypeTag.L_LONG_TALK,
        track=Track.M3,
        difficulty=1,
    )
    bad = replace(
        bad,
        transcript="A: Hello\nB: Thanks",
        turns=[
            {"speaker": "A", "text": "Hello"},
            {"speaker": "B", "text": "Thanks"},
            {"speaker": "A", "text": "Missing from transcript"},
            {"speaker": "B", "text": "Still missing"},
        ],
        sentences=[
            {"id": "s1", "text": "Hello"},
            {"id": "s2", "text": "Thanks"},
            {"id": "s3", "text": "Missing from transcript"},
            {"id": "s4", "text": "Still missing"},
        ],
    )

    _patch_provider_builder(monkeypatch, StaticProvider([bad]))

    job = _create_job(
        client,
        request_id="content-job-hard-listening-invalid",
        matrix=[
            {
                "track": "M3",
                "skill": "LISTENING",
                "typeTag": "L_LONG_TALK",
                "difficulty": 1,
                "count": 1,
            }
        ],
    )
    _run_job_once(db_session_factory, job_id=job["id"])

    listed = client.get(
        f"/internal/ai/content-generation/jobs/{job['id']}/candidates",
        headers=_internal_headers(),
    )
    assert listed.status_code == 200, listed.text
    assert listed.json()["items"][0]["failureCode"] == "OUTPUT_SENTENCE_ID_MISMATCH"


def test_hard_typetag_reading_missing_marker_maps_to_missing_field(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    bad = _valid_candidate(
        skill=Skill.READING,
        type_tag=ContentTypeTag.R_BLANK,
        track=Track.M3,
        difficulty=1,
    )
    bad = replace(
        bad,
        passage="Sentence one provides context. Sentence three confirms conclusion.",
    )

    _patch_provider_builder(monkeypatch, StaticProvider([bad]))

    job = _create_job(
        client,
        request_id="content-job-hard-reading-missing-marker",
        matrix=[
            {
                "track": "M3",
                "skill": "READING",
                "typeTag": "R_BLANK",
                "difficulty": 1,
                "count": 1,
            }
        ],
    )
    _run_job_once(db_session_factory, job_id=job["id"])

    listed = client.get(
        f"/internal/ai/content-generation/jobs/{job['id']}/candidates",
        headers=_internal_headers(),
    )
    assert listed.status_code == 200, listed.text
    assert listed.json()["items"][0]["failureCode"] == "OUTPUT_MISSING_FIELD"


def test_materialize_reading_and_listening_draft_success_and_not_auto_published(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    reading = _valid_candidate(skill=Skill.READING, type_tag=ContentTypeTag.R_MAIN_IDEA)
    listening = _valid_candidate(skill=Skill.LISTENING, type_tag=ContentTypeTag.L_DETAIL)

    _patch_provider_builder(monkeypatch, StaticProvider([reading, listening]))

    matrix = [
        {"track": "H2", "skill": "READING", "typeTag": "R_MAIN_IDEA", "difficulty": 3, "count": 1},
        {"track": "H2", "skill": "LISTENING", "typeTag": "L_DETAIL", "difficulty": 3, "count": 1},
    ]
    job = _create_job(client, request_id="content-job-materialize", matrix=matrix)

    result = _run_job_once(db_session_factory, job_id=job["id"])
    assert result.status == AIGenerationJobStatus.SUCCEEDED

    listed = client.get(
        f"/internal/ai/content-generation/jobs/{job['id']}/candidates",
        headers=_internal_headers(),
    )
    assert listed.status_code == 200, listed.text
    candidates = listed.json()["items"]
    assert len(candidates) == 2

    materialized_revision_ids: list[str] = []
    first_materialized_unit_id: str | None = None
    for item in candidates:
        response = client.post(
            f"/internal/ai/content-generation/candidates/{item['id']}/materialize-draft",
            headers=_internal_headers(),
        )
        assert response.status_code == 200, response.text
        payload = response.json()
        assert payload["revisionLifecycleStatus"] == ContentLifecycleStatus.DRAFT.value
        materialized_revision_ids.append(payload["contentRevisionId"])
        if first_materialized_unit_id is None:
            first_materialized_unit_id = payload["contentUnitId"]

    with db_session_factory() as db:
        for revision_id in materialized_revision_ids:
            revision = db.get(ContentUnitRevision, UUID(revision_id))
            assert revision is not None
            assert revision.lifecycle_status == ContentLifecycleStatus.DRAFT
            unit = db.get(ContentUnit, revision.content_unit_id)
            assert unit is not None
            assert unit.published_revision_id is None

    publish_without_validation = client.post(
        f"/internal/content/units/{first_materialized_unit_id}/publish",
        json={"revision_id": materialized_revision_ids[0]},
        headers=_internal_headers(),
    )
    assert publish_without_validation.status_code == 409
    assert publish_without_validation.json()["detail"] == "revision_not_validated"


def test_materialize_draft_propagates_job_source_metadata(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
    fake_ai_artifact_store: FakeAIArtifactStore,
) -> None:
    reading = _valid_candidate(
        skill=Skill.READING,
        type_tag=ContentTypeTag.R_BLANK,
        track=Track.M3,
        difficulty=1,
    )

    _patch_provider_builder(monkeypatch, StaticProvider([reading]))

    response = client.post(
        "/internal/ai/content-generation/jobs",
        json={
            "requestId": "content-job-source-propagation",
            "targetMatrix": [
                {
                    "track": "M3",
                    "skill": "READING",
                    "typeTag": "R_BLANK",
                    "difficulty": 1,
                    "count": 1,
                }
            ],
            "candidateCountPerTarget": 1,
            "dryRun": False,
            "metadata": {"source": "content_readiness_backfill"},
        },
        headers=_internal_headers(),
    )
    assert response.status_code == 201, response.text
    job = response.json()

    result = _run_job_once(db_session_factory, job_id=job["id"])
    assert result.status == AIGenerationJobStatus.SUCCEEDED

    listed = client.get(
        f"/internal/ai/content-generation/jobs/{job['id']}/candidates",
        headers=_internal_headers(),
    )
    assert listed.status_code == 200, listed.text
    candidate_id = listed.json()["items"][0]["id"]

    materialize = client.post(
        f"/internal/ai/content-generation/candidates/{candidate_id}/materialize-draft",
        headers=_internal_headers(),
    )
    assert materialize.status_code == 200, materialize.text
    revision_id = materialize.json()["contentRevisionId"]

    with db_session_factory() as db:
        revision = db.get(ContentUnitRevision, UUID(revision_id))
        assert revision is not None
        assert revision.metadata_json["source"] == "content_readiness_backfill"
        question = db.execute(
            select(ContentQuestion).where(ContentQuestion.content_unit_revision_id == revision.id)
        ).scalar_one()
        assert question.metadata_json["source"] == "content_readiness_backfill"


def test_l_response_materialize_records_generation_mode_and_compiler_version(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
    fake_ai_artifact_store: FakeAIArtifactStore,
) -> None:
    candidate = _valid_candidate(
        skill=Skill.LISTENING,
        type_tag=ContentTypeTag.L_RESPONSE,
        track=Track.M3,
        difficulty=1,
    )

    class LResponseProvider:
        def generate_candidates(self, *, context) -> ContentGenerationResult:
            del context
            compiled_payload = {
                "track": candidate.track.value,
                "skill": candidate.skill.value,
                "typeTag": candidate.type_tag.value,
                "difficulty": candidate.difficulty,
                "question": {
                    "stem": candidate.stem,
                },
            }
            raw_payload = {
                "track": candidate.track.value,
                "difficulty": candidate.difficulty,
                "typeTag": candidate.type_tag.value,
                "turns": candidate.turns,
                "responsePromptSpeaker": candidate.turns[-1]["speaker"],
                "correctResponseText": candidate.options["A"],
                "distractorResponseTexts": [
                    candidate.options["B"],
                    candidate.options["C"],
                    candidate.options["D"],
                    candidate.options["E"],
                ],
                "evidenceTurnIndexes": [2],
                "whyCorrectKo": candidate.why_correct_ko,
                "whyWrongKoByOption": {
                    "B": candidate.why_wrong_ko_by_option["B"],
                    "C": candidate.why_wrong_ko_by_option["C"],
                    "D": candidate.why_wrong_ko_by_option["D"],
                    "E": candidate.why_wrong_ko_by_option["E"],
                },
            }
            return ContentGenerationResult(
                provider_name="fake",
                model_name="gpt-5-mini",
                prompt_template_version="content-v1-listening-response-skeleton",
                raw_prompt=json.dumps({"requestId": "l-response-trace"}),
                raw_response=json.dumps({"candidates": [raw_payload]}),
                candidates=[candidate],
                raw_candidate_payloads=[raw_payload],
                compiled_candidate_payloads=[compiled_payload],
                generation_mode=L_RESPONSE_GENERATION_MODE,
                compiler_version=L_RESPONSE_COMPILER_VERSION,
            )

    _patch_provider_builder(monkeypatch, LResponseProvider())

    job = _create_job(
        client,
        request_id="content-job-l-response-trace",
        matrix=[
            {
                "track": "M3",
                "skill": "LISTENING",
                "typeTag": "L_RESPONSE",
                "difficulty": 1,
                "count": 1,
            }
        ],
    )
    result = _run_job_once(db_session_factory, job_id=job["id"])
    assert result.status == AIGenerationJobStatus.SUCCEEDED

    candidate_id = client.get(
        f"/internal/ai/content-generation/jobs/{job['id']}/candidates",
        headers=_internal_headers(),
    ).json()["items"][0]["id"]
    materialize = client.post(
        f"/internal/ai/content-generation/candidates/{candidate_id}/materialize-draft",
        headers=_internal_headers(),
    )
    assert materialize.status_code == 200, materialize.text

    with db_session_factory() as db:
        revision = db.get(ContentUnitRevision, UUID(materialize.json()["contentRevisionId"]))
        assert revision is not None
        assert revision.metadata_json["generationMode"] == L_RESPONSE_GENERATION_MODE
        assert revision.metadata_json["compilerVersion"] == L_RESPONSE_COMPILER_VERSION
        question = db.execute(
            select(ContentQuestion).where(ContentQuestion.content_unit_revision_id == revision.id)
        ).scalar_one()
        assert question.metadata_json["generationMode"] == L_RESPONSE_GENERATION_MODE
        assert question.metadata_json["compilerVersion"] == L_RESPONSE_COMPILER_VERSION


def test_h2_l_situation_materialize_records_generation_profile_and_timeout(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
    fake_ai_artifact_store: FakeAIArtifactStore,
) -> None:
    candidate = _valid_candidate(
        skill=Skill.LISTENING,
        type_tag=ContentTypeTag.L_SITUATION,
        track=Track.H2,
        difficulty=3,
    )
    line_1 = "Our group presentation is tomorrow morning, but the room is closed for repairs."
    line_2 = "Then we need another room, and the media lab is free only after lunch."
    line_3 = "I should ask the teacher whether we can change the presentation time."
    candidate = replace(
        candidate,
        transcript=f"Mina: {line_1}\nJoon: {line_2}\nMina: {line_3}",
        turns=[
            {"speaker": "Mina", "text": line_1},
            {"speaker": "Joon", "text": line_2},
            {"speaker": "Mina", "text": line_3},
        ],
        sentences=[
            {"id": "s1", "text": line_1},
            {"id": "s2", "text": line_2},
            {"id": "s3", "text": line_3},
        ],
        options={
            "A": "Explain the room problem and ask to move the presentation.",
            "B": "Wait in front of the closed room and hope it opens.",
            "C": "Cancel the presentation without telling the teacher.",
            "D": "Practice alone tonight and ignore the room issue.",
            "E": "Borrow sports equipment from the gym office.",
        },
        evidence_sentence_ids=["s1", "s2", "s3"],
        explanation=(
            "Option A is correct because the listener must combine the room problem, "
            "the time constraint, and the final intention."
        ),
    )

    class LSituationProvider:
        def generate_candidates(self, *, context) -> ContentGenerationResult:
            del context
            return ContentGenerationResult(
                provider_name="fake",
                model_name="gpt-5-mini",
                prompt_template_version="content-v1-listening-situation-contextual",
                raw_prompt=json.dumps({"requestId": "l-situation-trace"}),
                raw_response=json.dumps({"candidates": ["contextual"]}),
                candidates=[candidate],
                generation_mode=L_SITUATION_CONTEXTUAL_GENERATION_MODE,
                compiler_version=L_SITUATION_CONTEXTUAL_COMPILER_VERSION,
                generation_profile=L_SITUATION_CONTEXTUAL_GENERATION_PROFILE,
                timeout_seconds=60,
            )

    _patch_provider_builder(monkeypatch, LSituationProvider())

    job = _create_job(
        client,
        request_id="content-job-l-situation-trace",
        matrix=[
            {
                "track": "H2",
                "skill": "LISTENING",
                "typeTag": "L_SITUATION",
                "difficulty": 3,
                "count": 1,
            }
        ],
    )
    result = _run_job_once(db_session_factory, job_id=job["id"])
    assert result.status == AIGenerationJobStatus.SUCCEEDED

    candidate_id = client.get(
        f"/internal/ai/content-generation/jobs/{job['id']}/candidates",
        headers=_internal_headers(),
    ).json()["items"][0]["id"]
    materialize = client.post(
        f"/internal/ai/content-generation/candidates/{candidate_id}/materialize-draft",
        headers=_internal_headers(),
    )
    assert materialize.status_code == 200, materialize.text

    with db_session_factory() as db:
        revision = db.get(ContentUnitRevision, UUID(materialize.json()["contentRevisionId"]))
        assert revision is not None
        assert revision.metadata_json["generationMode"] == L_SITUATION_CONTEXTUAL_GENERATION_MODE
        assert revision.metadata_json["compilerVersion"] == L_SITUATION_CONTEXTUAL_COMPILER_VERSION
        assert (
            revision.metadata_json["generationProfile"] == L_SITUATION_CONTEXTUAL_GENERATION_PROFILE
        )
        assert revision.metadata_json["timeoutSeconds"] == 60
        question = db.execute(
            select(ContentQuestion).where(ContentQuestion.content_unit_revision_id == revision.id)
        ).scalar_one()
        assert (
            question.metadata_json["generationProfile"] == L_SITUATION_CONTEXTUAL_GENERATION_PROFILE
        )
        assert question.metadata_json["timeoutSeconds"] == 60


def test_artifact_upload_failure_marks_job_failed(
    client: TestClient,
    db_session_factory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    reading = _valid_candidate(skill=Skill.READING, type_tag=ContentTypeTag.R_MAIN_IDEA)

    _patch_provider_builder(monkeypatch, StaticProvider([reading]))
    monkeypatch.setattr(
        ai_content_generation_service, "get_ai_artifact_store", lambda: FailingArtifactStore()
    )

    matrix = [
        {"track": "H2", "skill": "READING", "typeTag": "R_MAIN_IDEA", "difficulty": 3, "count": 1}
    ]
    job = _create_job(client, request_id="content-job-artifact-fail", matrix=matrix)

    result = _run_job_once(db_session_factory, job_id=job["id"])
    assert result.status == AIGenerationJobStatus.FAILED

    with db_session_factory() as db:
        stored = db.get(AIContentGenerationJob, UUID(job["id"]))
        assert stored is not None
        assert stored.last_error_code == "ARTIFACT_UPLOAD_FAILED"


def test_retry_after_transient_failure_is_safe_and_no_duplicate_candidates(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    reading = _valid_candidate(skill=Skill.READING, type_tag=ContentTypeTag.R_MAIN_IDEA)

    class FlakyProvider:
        def __init__(self) -> None:
            self.calls = 0

        def generate_candidates(self, *, context):
            self.calls += 1
            if self.calls == 1:
                raise AIProviderError(
                    code="PROVIDER_TIMEOUT",
                    message="temporary timeout",
                    transient=True,
                )
            return StaticProvider([reading]).generate_candidates(context=context)

    flaky = FlakyProvider()
    _patch_provider_builder(monkeypatch, flaky)

    matrix = [
        {"track": "H2", "skill": "READING", "typeTag": "R_MAIN_IDEA", "difficulty": 3, "count": 1}
    ]
    job = _create_job(client, request_id="content-job-retry", matrix=matrix)

    first = _run_job_once(db_session_factory, job_id=job["id"])
    assert first.status == AIGenerationJobStatus.FAILED
    assert first.retry_after_seconds is not None

    retry = client.post(
        f"/internal/ai/content-generation/jobs/{job['id']}/retry",
        headers=_internal_headers(),
    )
    assert retry.status_code == 200, retry.text

    second = _run_job_once(db_session_factory, job_id=job["id"])
    assert second.status == AIGenerationJobStatus.SUCCEEDED

    with db_session_factory() as db:
        rows = (
            db.execute(
                select(AIContentGenerationCandidate)
                .where(AIContentGenerationCandidate.job_id == UUID(job["id"]))
                .order_by(AIContentGenerationCandidate.candidate_index.asc())
            )
            .scalars()
            .all()
        )
        assert len(rows) == 1
        assert rows[0].candidate_index == 1


def test_traceability_fields_and_artifact_keys_are_saved(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    candidate = _valid_candidate(skill=Skill.READING, type_tag=ContentTypeTag.R_MAIN_IDEA)
    _patch_provider_builder(monkeypatch, StaticProvider([candidate]))

    matrix = [
        {"track": "H2", "skill": "READING", "typeTag": "R_MAIN_IDEA", "difficulty": 3, "count": 1}
    ]
    job = _create_job(client, request_id="content-job-traceability", matrix=matrix)

    result = _run_job_once(db_session_factory, job_id=job["id"])
    assert result.status == AIGenerationJobStatus.SUCCEEDED

    with db_session_factory() as db:
        stored_job = db.get(AIContentGenerationJob, UUID(job["id"]))
        assert stored_job is not None
        assert stored_job.provider_name == "fake"
        assert stored_job.model_name == "ai-content-test-model"
        assert stored_job.prompt_template_version == "v-test"
        assert stored_job.input_artifact_object_key is not None
        assert stored_job.output_artifact_object_key is not None
        assert stored_job.candidate_snapshot_object_key is not None

        candidate_row = db.execute(
            select(AIContentGenerationCandidate).where(
                AIContentGenerationCandidate.job_id == stored_job.id
            )
        ).scalar_one()
        assert candidate_row.artifact_prompt_key is not None
        assert candidate_row.artifact_response_key is not None
        assert candidate_row.artifact_candidate_json_key is not None
        assert candidate_row.artifact_validation_report_key is not None
        assert candidate_row.status == AIContentGenerationCandidateStatus.VALID


def test_l_response_invalid_turn_count_maps_to_new_failure_code(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    bad = _valid_candidate(
        skill=Skill.LISTENING,
        type_tag=ContentTypeTag.L_RESPONSE,
        track=Track.M3,
        difficulty=1,
    )
    bad = replace(
        bad,
        turns=[
            {"speaker": "A", "text": "Hello"},
            {"speaker": "B", "text": "Hi"},
            {"speaker": "A", "text": "Extra turn"},
        ],
        sentences=[
            {"id": "s1", "text": "Hello"},
            {"id": "s2", "text": "Hi"},
            {"id": "s3", "text": "Extra turn"},
        ],
        transcript="A: Hello\nB: Hi\nA: Extra turn",
    )
    _patch_provider_builder(monkeypatch, StaticProvider([bad]))

    job = _create_job(
        client,
        request_id="content-job-l-response-turn-invalid",
        matrix=[
            {
                "track": "M3",
                "skill": "LISTENING",
                "typeTag": "L_RESPONSE",
                "difficulty": 1,
                "count": 1,
            }
        ],
    )
    result = _run_job_once(db_session_factory, job_id=job["id"])
    assert result.status == AIGenerationJobStatus.SUCCEEDED

    listed = client.get(
        f"/internal/ai/content-generation/jobs/{job['id']}/candidates",
        headers=_internal_headers(),
    )
    assert listed.status_code == 200, listed.text
    assert listed.json()["items"][0]["failureCode"] == "OUTPUT_INVALID_TURN_COUNT"


def test_l_response_duplicate_options_map_to_response_option_failure_code(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    bad = _valid_candidate(
        skill=Skill.LISTENING,
        type_tag=ContentTypeTag.L_RESPONSE,
        track=Track.M3,
        difficulty=1,
    )
    bad = replace(
        bad,
        options={
            "A": "Sure, I will.",
            "B": "Sure, I will.",
            "C": "Let's ask the teacher.",
            "D": "I left it at home.",
            "E": "The bus was late today.",
        },
    )
    _patch_provider_builder(monkeypatch, StaticProvider([bad]))

    job = _create_job(
        client,
        request_id="content-job-l-response-option-invalid",
        matrix=[
            {
                "track": "M3",
                "skill": "LISTENING",
                "typeTag": "L_RESPONSE",
                "difficulty": 1,
                "count": 1,
            }
        ],
    )
    result = _run_job_once(db_session_factory, job_id=job["id"])
    assert result.status == AIGenerationJobStatus.SUCCEEDED

    listed = client.get(
        f"/internal/ai/content-generation/jobs/{job['id']}/candidates",
        headers=_internal_headers(),
    )
    assert listed.status_code == 200, listed.text
    assert listed.json()["items"][0]["failureCode"] == "OUTPUT_INVALID_RESPONSE_OPTIONS"


def test_generated_candidate_materialization_is_not_auto_published_in_current_exam_surfaces(
    client: TestClient,
    db_session_factory,
    fake_ai_artifact_store: FakeAIArtifactStore,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    candidate = _valid_candidate(skill=Skill.READING, type_tag=ContentTypeTag.R_MAIN_IDEA)
    _patch_provider_builder(monkeypatch, StaticProvider([candidate]))

    matrix = [
        {"track": "H2", "skill": "READING", "typeTag": "R_MAIN_IDEA", "difficulty": 3, "count": 1}
    ]
    job = _create_job(client, request_id="content-job-draft-only", matrix=matrix)
    _run_job_once(db_session_factory, job_id=job["id"])

    candidates = client.get(
        f"/internal/ai/content-generation/jobs/{job['id']}/candidates",
        headers=_internal_headers(),
    ).json()["items"]
    response = client.post(
        f"/internal/ai/content-generation/candidates/{candidates[0]['id']}/materialize-draft",
        headers=_internal_headers(),
    )
    assert response.status_code == 200, response.text

    with db_session_factory() as db:
        revision = db.get(ContentUnitRevision, UUID(response.json()["contentRevisionId"]))
        assert revision is not None
        assert revision.lifecycle_status == ContentLifecycleStatus.DRAFT
        assert revision.published_at is None
