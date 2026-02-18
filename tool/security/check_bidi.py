#!/usr/bin/env python3
"""Fail if tracked UTF-8 text files contain bidi/hidden direction codepoints."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


TARGET_RANGES: tuple[tuple[int, int], ...] = (
    (0x202A, 0x202E),
    (0x2066, 0x2069),
    (0x200E, 0x200E),
    (0x200F, 0x200F),
)


def is_target_codepoint(value: int) -> bool:
    for start, end in TARGET_RANGES:
        if start <= value <= end:
            return True
    return False


def tracked_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise SystemExit(result.returncode)

    files: list[Path] = []
    for line in result.stdout.splitlines():
        if line:
            files.append(Path(line))
    return files


def main() -> int:
    found_any = False

    for path in tracked_files():
        try:
            raw = path.read_bytes()
        except OSError:
            continue

        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            # Skip binary / non-utf8 files safely.
            continue

        line = 1
        column = 1
        for char in text:
            codepoint = ord(char)
            if is_target_codepoint(codepoint):
                print(f"{path}:{line}:{column}: U+{codepoint:04X}")
                found_any = True

            if char == "\n":
                line += 1
                column = 1
            else:
                column += 1

    return 1 if found_any else 0


if __name__ == "__main__":
    raise SystemExit(main())
