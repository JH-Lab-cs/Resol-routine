from __future__ import annotations

import argparse
import json

from app.db.session import SessionLocal
from app.services.vocab_catalog_service import seed_vocab_catalog


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Seed backend vocab catalog from starter-pack data.",
    )
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON output.")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing.")
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Write catalog rows to the database.",
    )
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    dry_run = not args.execute
    if args.execute and args.dry_run:
        dry_run = False

    with SessionLocal() as db:
        result = seed_vocab_catalog(db, dry_run=dry_run)
        if not dry_run:
            db.commit()

    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print("Vocab catalog seed")
        print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
