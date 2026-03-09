from __future__ import annotations

import argparse
import json

from app.db.session import SessionLocal
from app.services.content_backfill_service import build_content_backfill_plan
from app.services.content_readiness_service import (
    build_b34_content_sync_gate,
    build_content_readiness_report,
)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Audit published content readiness for Daily and mock assembly.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON output.",
    )
    parser.add_argument(
        "--with-backfill-plan",
        action="store_true",
        help="Include the current content backfill plan preview.",
    )
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
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    with SessionLocal() as db:
        report = build_content_readiness_report(db)
        backfill_plan = None
        if args.with_backfill_plan:
            backfill_plan = build_content_backfill_plan(
                db,
                max_targets_per_run=args.max_targets_per_run,
                max_candidates_per_run=args.max_candidates_per_run,
            )
            report["backfillPlan"] = backfill_plan
        report["b34ContentSyncGate"] = build_b34_content_sync_gate(
            report,
            backfill_plan=backfill_plan,
        )

    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print("Content readiness audit")
        print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
