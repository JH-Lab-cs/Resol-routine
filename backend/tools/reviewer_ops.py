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


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Reviewer and operations CLI for content lifecycle and mock assembly.",
    )
    parser.add_argument("--json", action="store_true", help="Print command output as JSON.")

    subparsers = parser.add_subparsers(dest="command", required=True)

    list_drafts = subparsers.add_parser("list-drafts", help="List content draft revisions.")
    list_drafts.add_argument("--track", required=False)
    list_drafts.add_argument("--skill", required=False)
    list_drafts.add_argument("--typeTag", required=False)
    list_drafts.add_argument("--page-size", type=int, default=20)
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
    mock_assemble.add_argument("--track", required=True, choices=["M3", "H1", "H2", "H3"])
    mock_assemble.add_argument("--periodKey", required=True)
    mock_assemble.add_argument("--seedOverride", required=False)
    mock_assemble.add_argument("--dryRun", action="store_true")
    mock_assemble.add_argument("--forceRebuild", action="store_true")
    mock_assemble.set_defaults(handler=_cmd_mock_assemble)

    return parser


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
        raise RuntimeError(f"HTTP {exc.code} {path}: {body}") from exc
    except urllib_error.URLError as exc:
        raise RuntimeError(f"Failed to reach backend API: {exc.reason}") from exc


def _resolve_unit_for_revision(revision_id: str) -> str:
    questions = _request(
        method="GET",
        path="/internal/content/questions",
        query={"revision_id": revision_id, "page": 1, "page_size": 1},
    )
    items = questions.get("items", [])
    if items:
        return str(items[0]["unit_id"])

    # Fallback for edge cases where revision has no question rows in query response.
    page = 1
    while True:
        units = _request(
            method="GET",
            path="/internal/content/units",
            query={"page": page, "page_size": 100},
        )
        unit_items = units.get("items", [])
        if not unit_items:
            break
        for unit in unit_items:
            revisions = _request(
                method="GET",
                path=f"/internal/content/units/{unit['id']}/revisions",
            )
            for revision in revisions.get("items", []):
                if str(revision["id"]) == revision_id:
                    return str(unit["id"])
        page += 1

    raise RuntimeError(f"Unable to resolve unit for revision {revision_id}.")


def _emit(*, args: argparse.Namespace, payload: Any) -> int:
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


def _cmd_list_drafts(args: argparse.Namespace) -> int:
    page = 1
    results: list[dict[str, Any]] = []
    while True:
        units = _request(
            method="GET",
            path="/internal/content/units",
            query={
                "page": page,
                "page_size": args.page_size,
                "track": args.track,
                "skill": args.skill,
            },
        )
        unit_items = units.get("items", [])
        if not unit_items:
            break
        for unit in unit_items:
            revisions = _request(
                method="GET",
                path=f"/internal/content/units/{unit['id']}/revisions",
            )
            for revision in revisions.get("items", []):
                if revision.get("lifecycle_status") != "DRAFT":
                    continue
                if args.typeTag is not None:
                    question_type_tags = [
                        str(question.get("metadata_json", {}).get("typeTag", "")).upper()
                        for question in revision.get("questions", [])
                    ]
                    if args.typeTag.upper() not in question_type_tags:
                        continue
                results.append(
                    {
                        "unitId": unit["id"],
                        "unitExternalId": unit["external_id"],
                        "skill": unit["skill"],
                        "track": unit["track"],
                        "revisionId": revision["id"],
                        "revisionNo": revision["revision_no"],
                        "canPublish": revision["can_publish"],
                        "generatorVersion": revision["generator_version"],
                    }
                )
        page += 1
    return _emit(args=args, payload={"items": results, "count": len(results)})


def _cmd_show_revision(args: argparse.Namespace) -> int:
    unit_id = _resolve_unit_for_revision(args.revision_id)
    revisions = _request(
        method="GET",
        path=f"/internal/content/units/{unit_id}/revisions",
    )
    for revision in revisions.get("items", []):
        if str(revision["id"]) == args.revision_id:
            return _emit(args=args, payload=revision)
    raise RuntimeError(f"Revision {args.revision_id} not found.")


def _cmd_validate(args: argparse.Namespace) -> int:
    unit_id = _resolve_unit_for_revision(args.revision_id)
    response = _request(
        method="POST",
        path=f"/internal/content/units/{unit_id}/revisions/{args.revision_id}/validate",
        payload={"validator_version": args.validator},
    )
    return _emit(args=args, payload=response)


def _cmd_review(args: argparse.Namespace) -> int:
    unit_id = _resolve_unit_for_revision(args.revision_id)
    response = _request(
        method="POST",
        path=f"/internal/content/units/{unit_id}/revisions/{args.revision_id}/review",
        payload={"reviewer_identity": args.reviewer},
    )
    return _emit(args=args, payload=response)


def _cmd_publish(args: argparse.Namespace) -> int:
    unit_id = _resolve_unit_for_revision(args.revision_id)
    response = _request(
        method="POST",
        path=f"/internal/content/units/{unit_id}/publish",
        payload={"revision_id": args.revision_id},
    )
    return _emit(args=args, payload=response)


def _cmd_archive(args: argparse.Namespace) -> int:
    unit_id = _resolve_unit_for_revision(args.revision_id)
    response = _request(
        method="POST",
        path=f"/internal/content/units/{unit_id}/archive",
    )
    payload = {
        "archived": response,
        "reason": args.reason,
        "note": "The API archives the owning content unit.",
    }
    return _emit(args=args, payload=payload)


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


def main() -> int:
    parser = _build_parser()
    args = parser.parse_args()
    handler = args.handler
    try:
        return int(handler(args))
    except RuntimeError as exc:
        error_payload = {"error": str(exc)}
        if getattr(args, "json", False):
            print(json.dumps(error_payload, ensure_ascii=False, indent=2), file=sys.stderr)
        else:
            print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
