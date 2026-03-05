#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

_GIT_BIN = shutil.which("git")
if _GIT_BIN is None:
    raise RuntimeError("git executable not found in PATH")


def _run_git(*args: str) -> str:
    result = subprocess.run(  # noqa: S603
        [_GIT_BIN, *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def _resolve_repo_root() -> Path:
    return Path(_run_git("rev-parse", "--show-toplevel"))


def _resolve_default_refs() -> tuple[str, str]:
    head = _run_git("rev-parse", "HEAD")
    try:
        base = _run_git("rev-parse", "HEAD~1")
    except subprocess.CalledProcessError:
        base = head
    return base, head


def _collect_changed_backend_python_files(*, repo_root: Path, base: str, head: str) -> list[str]:
    if base == head:
        return []

    result = subprocess.run(  # noqa: S603
        [
            _GIT_BIN,
            "-C",
            str(repo_root),
            "diff",
            "--name-only",
            "--diff-filter=ACMR",
            base,
            head,
        ],
        # Arguments are fixed git flags and trusted commit refs from CI/local git state.
        check=True,
        capture_output=True,
        text=True,
    )

    changed_files: set[str] = set()
    for raw_line in result.stdout.splitlines():
        path = raw_line.strip()
        if not path.startswith("backend/"):
            continue
        if not path.endswith(".py"):
            continue
        backend_relative_path = path.removeprefix("backend/")
        if backend_relative_path:
            changed_files.add(backend_relative_path)

    return sorted(changed_files)


def main() -> int:
    parser = argparse.ArgumentParser(description="List changed backend Python files.")
    parser.add_argument("--base", dest="base_ref", default=None)
    parser.add_argument("--head", dest="head_ref", default=None)
    args = parser.parse_args()

    if (args.base_ref is None) ^ (args.head_ref is None):
        parser.error("--base and --head must be provided together.")

    repo_root = _resolve_repo_root()
    if args.base_ref is None:
        base_ref, head_ref = _resolve_default_refs()
    else:
        base_ref, head_ref = args.base_ref, args.head_ref

    try:
        files = _collect_changed_backend_python_files(
            repo_root=repo_root,
            base=base_ref,
            head=head_ref,
        )
    except subprocess.CalledProcessError as exc:
        print(exc.stderr.strip(), file=sys.stderr)
        return 1

    for file_path in files:
        print(file_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
