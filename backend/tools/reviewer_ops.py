#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any
from urllib import error as urllib_error
from urllib import parse as urllib_parse
from urllib import request as urllib_request

from app.db.session import SessionLocal
from app.models.enums import Skill, Track
from app.services.content_backfill_service import (
    BackfillFilter,
    ContentBackfillExecutionError,
    build_content_backfill_plan,
    enqueue_content_backfill_jobs,
)
from app.services.reviewer_batch_service import (
    ReviewerBatchFilter,
    batch_publish_content_revisions,
    batch_review_content_revisions,
    batch_validate_content_revisions,
)


class CliRequestError(RuntimeError):
    def __init__(
        self,
        *,
        path: str,
        status_code: int,
        detail: Any,
        error_code: str,
        body: Any,
    ) -> None:
        self.path = path
        self.status_code = status_code
        self.detail = detail
        self.error_code = error_code
        self.body = body
        super().__init__(f"HTTP {status_code} {path}: {detail}")


TRACK_CHOICES = [track.value for track in Track]
SKILL_CHOICES = [skill.value for skill in Skill]


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Reviewer and operations CLI for content lifecycle and mock assembly.",
    )
    parser.add_argument("--json", action="store_true", help="Print command output as JSON.")

    subparsers = parser.add_subparsers(dest="command", required=True)

    list_drafts = subparsers.add_parser("list-drafts", help="List content draft revisions.")
    _add_revision_filters(list_drafts, include_pagination=True)
    list_drafts.set_defaults(handler=_cmd_list_drafts)

    show_revision = subparsers.add_parser("show-revision", help="Show content revision details.")
    show_revision.add_argument("revision_id")
    show_revision.set_defaults(handler=_cmd_show_revision)

    validate = subparsers.add_parser("validate", help="Validate a revision.")
    validate.add_argument("revision_id")
    validate.add_argument("--validator", required=True)
    validate.set_defaults(handler=_cmd_validate)

    review = subparsers.add_parser("review", help="Review a revision.")
    review.add_argument("revision_id")
    review.add_argument("--reviewer", required=True)
    review.set_defaults(handler=_cmd_review)

    publish = subparsers.add_parser("publish", help="Publish a revision.")
    publish.add_argument("revision_id")
    publish.set_defaults(handler=_cmd_publish)

    archive = subparsers.add_parser("archive", help="Archive the owning unit of a revision.")
    archive.add_argument("revision_id")
    archive.add_argument("--reason", required=True)
    archive.set_defaults(handler=_cmd_archive)

    tts_generate = subparsers.add_parser(
        "tts-generate",
        help="Ensure TTS audio for a listening draft revision.",
    )
    tts_generate.add_argument("revision_id")
    tts_generate.add_argument(
        "--provider",
        default=os.getenv("REVIEWER_OPS_TTS_PROVIDER", "fake"),
    )
    tts_generate.add_argument(
        "--model",
        default=os.getenv("REVIEWER_OPS_TTS_MODEL", "fake-tts-model"),
    )
    tts_generate.add_argument("--voice", default=os.getenv("REVIEWER_OPS_TTS_VOICE", "alloy"))
    tts_generate.add_argument(
        "--speed",
        type=float,
        default=float(os.getenv("REVIEWER_OPS_TTS_SPEED", "1.0")),
    )
    tts_generate.add_argument("--force-regen", action="store_true")
    tts_generate.set_defaults(handler=_cmd_tts_generate)

    mock_assemble = subparsers.add_parser("mock-assemble", help="Create mock assembly job.")
    mock_assemble.add_argument("--type", required=True, choices=["weekly", "monthly"])
    mock_assemble.add_argument("--track", required=True, choices=TRACK_CHOICES)
    mock_assemble.add_argument("--periodKey", required=True)
    mock_assemble.add_argument("--seedOverride", required=False)
    mock_assemble.add_argument("--dryRun", action="store_true")
    mock_assemble.add_argument("--forceRebuild", action="store_true")
    mock_assemble.set_defaults(handler=_cmd_mock_assemble)

    backfill_plan = subparsers.add_parser(
        "backfill-plan",
        help="Build a readiness backfill plan without creating AI jobs.",
    )
    _add_batch_filters(backfill_plan)
    _add_backfill_budget_args(backfill_plan)
    backfill_plan.set_defaults(handler=_cmd_backfill_plan)

    backfill_enqueue = subparsers.add_parser(
        "backfill-enqueue",
        help="Convert readiness deficits into AI content generation jobs.",
    )
    _add_batch_filters(backfill_enqueue)
    _add_backfill_budget_args(backfill_enqueue)
    backfill_enqueue.add_argument("--provider-override", dest="provider_override")
    backfill_enqueue.add_argument("--execute", action="store_true")
    backfill_enqueue.set_defaults(handler=_cmd_backfill_enqueue)

    batch_validate = subparsers.add_parser(
        "batch-validate",
        help="Validate matching draft revisions in bulk.",
    )
    _add_batch_filters(batch_validate)
    batch_validate.add_argument("--validator", required=True)
    batch_validate.set_defaults(handler=_cmd_batch_validate)

    batch_review = subparsers.add_parser(
        "batch-review",
        help="Review matching draft revisions in bulk.",
    )
    _add_batch_filters(batch_review)
    batch_review.add_argument("--reviewer", required=True)
    batch_review.set_defaults(handler=_cmd_batch_review)

    batch_publish = subparsers.add_parser(
        "batch-publish",
        help="Publish matching validated+reviewed drafts in bulk.",
    )
    _add_batch_filters(batch_publish)
    batch_publish.add_argument("--confirm", action="store_true")
    batch_publish.set_defaults(handler=_cmd_batch_publish)

    return parser


def _add_revision_filters(parser: argparse.ArgumentParser, *, include_pagination: bool) -> None:
    parser.add_argument("--track", required=False, choices=TRACK_CHOICES)
    parser.add_argument("--skill", required=False, choices=SKILL_CHOICES)
    parser.add_argument("--type-tag", "--typeTag", dest="type_tag", required=False)
    if include_pagination:
        parser.add_argument("--page", type=int, default=1)
        parser.add_argument("--page-size", type=int, default=20)


def _add_batch_filters(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--track", required=False, choices=TRACK_CHOICES)
    parser.add_argument("--skill", required=False, choices=SKILL_CHOICES)
    parser.add_argument("--type-tag", "--typeTag", dest="type_tag", required=False)
    parser.add_argument("--difficulty-min", dest="difficulty_min", type=int, required=False)
    parser.add_argument("--difficulty-max", dest="difficulty_max", type=int, required=False)
    parser.add_argument("--limit", type=int, required=False)


def _add_backfill_budget_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--max-targets-per-run",
        dest="max_targets_per_run",
        type=int,
    )
    parser.add_argument(
        "--max-candidates-per-run",
        dest="max_candidates_per_run",
        type=int,
    )


def _base_url() -> str:
    return os.getenv("REVIEWER_OPS_BASE_URL", "http://127.0.0.1:8000").rstrip("/")


def _internal_api_key() -> str:
    value = os.getenv("CONTENT_PIPELINE_API_KEY")
    if value is None or not value.strip():
        raise RuntimeError("CONTENT_PIPELINE_API_KEY is required.")
    return value.strip()


def _request(
    *,
    method: str,
    path: str,
    payload: dict[str, Any] | None = None,
    query: dict[str, Any] | None = None,
) -> Any:
    url = f"{_base_url()}{path}"
    if query:
        encoded_query = urllib_parse.urlencode(
            {key: value for key, value in query.items() if value is not None},
            doseq=True,
        )
        url = f"{url}?{encoded_query}"

    data: bytes | None = None
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")

    request = urllib_request.Request(  # noqa: S310
        url=url,
        data=data,
        method=method.upper(),
        headers={
            "Content-Type": "application/json",
            "X-Internal-Api-Key": _internal_api_key(),
        },
    )
    try:
        with urllib_request.urlopen(request, timeout=30) as response:  # noqa: S310
            body = response.read()
            if not body:
                return {}
            return json.loads(body.decode("utf-8"))
    except urllib_error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        parsed_body: Any
        try:
            parsed_body = json.loads(body)
        except json.JSONDecodeError:
            parsed_body = {"detail": body, "errorCode": "http_error"}
        detail = parsed_body.get("detail", body) if isinstance(parsed_body, dict) else body
        error_code = (
            str(parsed_body.get("errorCode", "http_error"))
            if isinstance(parsed_body, dict)
            else "http_error"
        )
        raise CliRequestError(
            path=path,
            status_code=exc.code,
            detail=detail,
            error_code=error_code,
            body=parsed_body,
        ) from exc
    except urllib_error.URLError as exc:
        raise RuntimeError(f"Failed to reach backend API: {exc.reason}") from exc


def _get_revision(revision_id: str) -> dict[str, Any]:
    return _request(
        method="GET",
        path=f"/internal/content/revisions/{revision_id}",
    )


def _emit(*, args: argparse.Namespace, payload: Any) -> int:
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


def _cmd_list_drafts(args: argparse.Namespace) -> int:
    response = _request(
        method="GET",
        path="/internal/content/revisions",
        query={
            "status": "DRAFT",
            "track": args.track,
            "skill": args.skill,
            "typeTag": args.type_tag,
            "page": args.page,
            "pageSize": args.page_size,
        },
    )
    return _emit(args=args, payload=response)


def _cmd_show_revision(args: argparse.Namespace) -> int:
    return _emit(args=args, payload=_get_revision(args.revision_id))


def _cmd_validate(args: argparse.Namespace) -> int:
    revision = _get_revision(args.revision_id)
    response = _request(
        method="POST",
        path=f"/internal/content/units/{revision['unit_id']}/revisions/{args.revision_id}/validate",
        payload={"validator_version": args.validator},
    )
    return _emit(args=args, payload=response)


def _cmd_review(args: argparse.Namespace) -> int:
    revision = _get_revision(args.revision_id)
    response = _request(
        method="POST",
        path=f"/internal/content/units/{revision['unit_id']}/revisions/{args.revision_id}/review",
        payload={"reviewer_identity": args.reviewer},
    )
    return _emit(args=args, payload=response)


def _cmd_publish(args: argparse.Namespace) -> int:
    revision = _get_revision(args.revision_id)
    response = _request(
        method="POST",
        path=f"/internal/content/units/{revision['unit_id']}/publish",
        payload={"revision_id": args.revision_id},
    )
    return _emit(args=args, payload=response)


def _cmd_archive(args: argparse.Namespace) -> int:
    response = _request(
        method="POST",
        path=f"/internal/content/revisions/{args.revision_id}/archive",
        payload={"reason": args.reason},
    )
    return _emit(args=args, payload=response)


def _cmd_tts_generate(args: argparse.Namespace) -> int:
    response = _request(
        method="POST",
        path=f"/internal/ai/tts/revisions/{args.revision_id}/ensure-audio",
        payload={
            "provider": args.provider,
            "model": args.model,
            "voice": args.voice,
            "speed": args.speed,
            "forceRegen": args.force_regen,
        },
    )
    return _emit(args=args, payload=response)


def _cmd_mock_assemble(args: argparse.Namespace) -> int:
    exam_type = "WEEKLY" if args.type.lower() == "weekly" else "MONTHLY"
    response = _request(
        method="POST",
        path="/internal/mock-assembly/jobs",
        payload={
            "examType": exam_type,
            "track": args.track,
            "periodKey": args.periodKey,
            "seedOverride": args.seedOverride,
            "dryRun": args.dryRun,
            "forceRebuild": args.forceRebuild,
        },
    )
    return _emit(args=args, payload=response)


def _cmd_backfill_plan(args: argparse.Namespace) -> int:
    with SessionLocal() as db:
        payload = build_content_backfill_plan(
            db,
            filters=_backfill_filters_from_args(args),
            max_targets_per_run=args.max_targets_per_run,
            max_candidates_per_run=args.max_candidates_per_run,
        )
    return _emit(args=args, payload=payload)


def _cmd_backfill_enqueue(args: argparse.Namespace) -> int:
    with SessionLocal() as db:
        payload = enqueue_content_backfill_jobs(
            db,
            filters=_backfill_filters_from_args(args),
            max_targets_per_run=args.max_targets_per_run,
            max_candidates_per_run=args.max_candidates_per_run,
            provider_override=args.provider_override,
            execute=args.execute,
        )
    return _emit(args=args, payload=payload)


def _cmd_batch_validate(args: argparse.Namespace) -> int:
    with SessionLocal() as db:
        payload = batch_validate_content_revisions(
            db,
            filters=_reviewer_filters_from_args(args),
            validator_version=args.validator,
        )
        db.commit()
    return _emit(args=args, payload=payload)


def _cmd_batch_review(args: argparse.Namespace) -> int:
    with SessionLocal() as db:
        payload = batch_review_content_revisions(
            db,
            filters=_reviewer_filters_from_args(args),
            reviewer_identity=args.reviewer,
        )
        db.commit()
    return _emit(args=args, payload=payload)


def _cmd_batch_publish(args: argparse.Namespace) -> int:
    with SessionLocal() as db:
        payload = batch_publish_content_revisions(
            db,
            filters=_reviewer_filters_from_args(args),
            confirm=args.confirm,
        )
        db.commit()
    return _emit(args=args, payload=payload)


def _backfill_filters_from_args(args: argparse.Namespace) -> BackfillFilter:
    return BackfillFilter(
        track=Track(args.track) if args.track is not None else None,
        skill=Skill(args.skill) if args.skill is not None else None,
        type_tag=args.type_tag,
        difficulty_min=args.difficulty_min,
        difficulty_max=args.difficulty_max,
        limit=args.limit,
    )


def _reviewer_filters_from_args(args: argparse.Namespace) -> ReviewerBatchFilter:
    return ReviewerBatchFilter(
        track=Track(args.track) if args.track is not None else None,
        skill=Skill(args.skill) if args.skill is not None else None,
        type_tag=args.type_tag,
        difficulty_min=args.difficulty_min,
        difficulty_max=args.difficulty_max,
        limit=args.limit,
    )


def main() -> int:
    parser = _build_parser()
    args = parser.parse_args()
    handler = args.handler
    try:
        return int(handler(args))
    except CliRequestError as exc:
        error_payload = {
            "error": {
                "statusCode": exc.status_code,
                "code": exc.error_code,
                "detail": exc.detail,
                "path": exc.path,
            }
        }
        if getattr(args, "json", False):
            print(json.dumps(error_payload, ensure_ascii=False, indent=2))
        else:
            print(str(exc), file=sys.stderr)
        return 1
    except ContentBackfillExecutionError as exc:
        error_payload = {
            "error": {
                "statusCode": 409,
                "code": exc.code,
                "detail": exc.message,
            }
        }
        if getattr(args, "json", False):
            print(json.dumps(error_payload, ensure_ascii=False, indent=2))
        else:
            print(f"{exc.code}: {exc.message}", file=sys.stderr)
        return 1
    except Exception as exc:
        error_payload = {"error": str(exc)}
        if getattr(args, "json", False):
            print(json.dumps(error_payload, ensure_ascii=False, indent=2))
        else:
            print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
