from __future__ import annotations

import argparse
import json

from app.db.session import SessionLocal
from app.services.dev_content_seed_service import seed_dev_content_and_mock_samples


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Seed dev/qa published content and mock samples into the local "
            "backend database."
        ),
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON output.",
    )
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    with SessionLocal() as db:
        result = seed_dev_content_and_mock_samples(db)
        db.commit()

    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print("Seeded dev/qa content fixtures.")
        print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
