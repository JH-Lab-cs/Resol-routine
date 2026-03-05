#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import PurePosixPath


def _to_mypy_target(path: str) -> str | None:
    normalized = path.strip().replace("\\", "/")
    if not normalized or not normalized.endswith(".py"):
        return None
    pure_path = PurePosixPath(normalized)
    if not pure_path.parts or pure_path.parts[0] != "app":
        return None

    if pure_path.name == "__init__.py":
        module_parts = list(pure_path.parts[:-1])
    else:
        module_parts = list(pure_path.parts)
        module_parts[-1] = module_parts[-1][:-3]

    if not module_parts:
        return None
    return ".".join(module_parts)


def _read_paths_from_stdin() -> list[str]:
    return [line.strip() for line in sys.stdin if line.strip()]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Map changed backend Python file paths to mypy module targets."
    )
    parser.add_argument("paths", nargs="*")
    args = parser.parse_args()

    input_paths = args.paths or _read_paths_from_stdin()
    targets = sorted(
        {
            target
            for path in input_paths
            if (target := _to_mypy_target(path)) is not None
        }
    )

    for target in targets:
        print(target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
