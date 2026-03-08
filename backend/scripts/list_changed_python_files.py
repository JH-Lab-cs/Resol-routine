#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
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


@dataclass(frozen=True)
class DiffSelection:
    base: str
    head: str
    strategy: str
    base_ref: str | None = None


def _git_ref_exists(ref: str) -> bool:
    try:
        _run_git("rev-parse", "--verify", ref)
        return True
    except subprocess.CalledProcessError:
        return False


def _resolve_base_ref_candidate(ref_name: str) -> str | None:
    normalized = ref_name.strip()
    if not normalized:
        return None
    if _git_ref_exists(normalized):
        return normalized
    remote_ref = f"origin/{normalized}"
    if _git_ref_exists(remote_ref):
        return remote_ref
    local_branch_ref = f"refs/heads/{normalized}"
    if _git_ref_exists(local_branch_ref):
        return normalized
    return None


def _resolve_merge_base_target_ref() -> str | None:
    env_candidates = [
        os.getenv("STRICT_BASE_REF"),
        os.getenv("TARGET_BRANCH"),
        os.getenv("PR_BASE_REF"),
        os.getenv("GITHUB_BASE_REF"),
    ]
    for candidate in env_candidates:
        if candidate is None:
            continue
        resolved = _resolve_base_ref_candidate(candidate)
        if resolved is not None:
            return resolved

    try:
        upstream_ref = _run_git("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}")
    except subprocess.CalledProcessError:
        upstream_ref = None
    if upstream_ref and _git_ref_exists(upstream_ref):
        return upstream_ref

    preferred_refs = (
        "origin/main",
        "main",
        "origin/master",
        "master",
    )
    for ref in preferred_refs:
        if _git_ref_exists(ref):
            return ref

    try:
        symbolic_origin_head = _run_git("symbolic-ref", "refs/remotes/origin/HEAD")
    except subprocess.CalledProcessError:
        return None
    if _git_ref_exists(symbolic_origin_head):
        return symbolic_origin_head
    return None


def _resolve_default_refs() -> DiffSelection:
    head = _run_git("rev-parse", "HEAD")
    merge_base_target = _resolve_merge_base_target_ref()
    if merge_base_target is not None:
        try:
            base = _run_git("merge-base", "HEAD", merge_base_target)
        except subprocess.CalledProcessError:
            base = head
        else:
            return DiffSelection(
                base=base,
                head=head,
                strategy="merge-base",
                base_ref=merge_base_target,
            )

    try:
        base = _run_git("rev-parse", "HEAD~1")
    except subprocess.CalledProcessError:
        base = head
    return DiffSelection(base=base, head=head, strategy="head-range")


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


def _collect_local_working_tree_backend_python_files(*, repo_root: Path) -> list[str]:
    tracked_result = subprocess.run(  # noqa: S603
        [
            _GIT_BIN,
            "-C",
            str(repo_root),
            "diff",
            "--name-only",
            "--diff-filter=ACMR",
            "HEAD",
            "--",
            "backend",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    untracked_result = subprocess.run(  # noqa: S603
        [
            _GIT_BIN,
            "-C",
            str(repo_root),
            "ls-files",
            "--others",
            "--exclude-standard",
            "--",
            "backend",
        ],
        check=True,
        capture_output=True,
        text=True,
    )

    changed_files: set[str] = set()
    for raw_line in (*tracked_result.stdout.splitlines(), *untracked_result.stdout.splitlines()):
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
        selection = _resolve_default_refs()
    else:
        selection = DiffSelection(
            base=args.base_ref,
            head=args.head_ref,
            strategy="explicit-range",
        )

    try:
        files = _collect_changed_backend_python_files(
            repo_root=repo_root,
            base=selection.base,
            head=selection.head,
        )
        if args.base_ref is None:
            local_working_tree_files = _collect_local_working_tree_backend_python_files(
                repo_root=repo_root
            )
            if local_working_tree_files:
                print(
                    "Including local working tree backend Python changes relative to HEAD.",
                    file=sys.stderr,
                )
            files = sorted(set(files) | set(local_working_tree_files))
    except subprocess.CalledProcessError as exc:
        print(exc.stderr.strip(), file=sys.stderr)
        return 1

    print(
        "Changed-file comparison:",
        selection.strategy,
        f"base={selection.base}",
        f"head={selection.head}",
        file=sys.stderr,
    )
    if selection.base_ref is not None:
        print(f"Changed-file merge-base target: {selection.base_ref}", file=sys.stderr)

    for file_path in files:
        print(file_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
