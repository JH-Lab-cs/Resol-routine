from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path


def _load_changed_files_module():
    script_path = Path(__file__).resolve().parents[1] / "scripts" / "list_changed_python_files.py"
    spec = importlib.util.spec_from_file_location("list_changed_python_files", script_path)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _called_process_error(*args: str) -> subprocess.CalledProcessError:
    return subprocess.CalledProcessError(returncode=1, cmd=["git", *args], stderr="not found")


def test_resolve_default_refs_uses_upstream_tracking_branch(monkeypatch) -> None:
    module = _load_changed_files_module()

    responses = {
        ("rev-parse", "HEAD"): "head-sha",
        (
            "rev-parse",
            "--abbrev-ref",
            "--symbolic-full-name",
            "@{upstream}",
        ): "origin/codex/a2-start",
        ("rev-parse", "--verify", "origin/codex/a2-start"): "origin-branch-sha",
        ("merge-base", "HEAD", "origin/codex/a2-start"): "upstream-merge-base-sha",
    }

    def fake_run_git(*args: str) -> str:
        try:
            return responses[args]
        except KeyError as exc:
            raise _called_process_error(*args) from exc

    monkeypatch.setattr(module, "_run_git", fake_run_git)

    selection = module._resolve_default_refs()

    assert selection.strategy == "merge-base"
    assert selection.base == "upstream-merge-base-sha"
    assert selection.head == "head-sha"
    assert selection.base_ref == "origin/codex/a2-start"


def test_resolve_default_refs_prefers_pr_base_ref_over_upstream(monkeypatch) -> None:
    module = _load_changed_files_module()

    responses = {
        ("rev-parse", "HEAD"): "head-sha",
        ("rev-parse", "--verify", "main"): subprocess.CalledProcessError(1, ["git"]),
        ("rev-parse", "--verify", "origin/main"): "origin-main-sha",
        ("merge-base", "HEAD", "origin/main"): "pr-merge-base-sha",
    }

    def fake_run_git(*args: str) -> str:
        response = responses.get(args)
        if isinstance(response, subprocess.CalledProcessError):
            raise response
        if response is None:
            raise _called_process_error(*args)
        return response

    monkeypatch.setattr(module, "_run_git", fake_run_git)
    monkeypatch.setenv("GITHUB_BASE_REF", "main")

    selection = module._resolve_default_refs()

    assert selection.strategy == "merge-base"
    assert selection.base == "pr-merge-base-sha"
    assert selection.base_ref == "origin/main"


def test_resolve_default_refs_falls_back_to_head_range(monkeypatch) -> None:
    module = _load_changed_files_module()

    responses = {
        ("rev-parse", "HEAD"): "head-sha",
        ("rev-parse", "HEAD~1"): "previous-sha",
    }

    def fake_run_git(*args: str) -> str:
        try:
            return responses[args]
        except KeyError as exc:
            raise _called_process_error(*args) from exc

    monkeypatch.setattr(module, "_run_git", fake_run_git)

    selection = module._resolve_default_refs()

    assert selection.strategy == "head-range"
    assert selection.base == "previous-sha"
    assert selection.head == "head-sha"
    assert selection.base_ref is None
