from __future__ import annotations

import argparse
import json

from app.db.session import SessionLocal
from app.services.vocab_readiness_service import build_vocab_readiness_report


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Audit backend vocab catalog readiness by track band.",
    )
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON output.")
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    with SessionLocal() as db:
        report = build_vocab_readiness_report(db)

    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print("Vocab catalog readiness audit")
        print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
