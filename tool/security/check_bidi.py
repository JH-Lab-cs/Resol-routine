#!/usr/bin/env python3
"""Scan tracked UTF-8 files for hidden/bidi Unicode codepoints."""

from __future__ import annotations

import subprocess
import sys
import unicodedata
from pathlib import Path


TARGET_RANGES: tuple[tuple[int, int], ...] = (
    (0x202A, 0x202E),
    (0x2066, 0x2069),
)

TARGET_POINTS: set[int] = {
    0x200E,
    0x200F,
    0x200B,
    0x200C,
    0x200D,
    0x2060,
    0xFEFF,
    0x00AD,
    0x061C,
    0x034F,
}


def is_target_codepoint(codepoint: int) -> bool:
    if codepoint in TARGET_POINTS:
        return True

    for start, end in TARGET_RANGES:
        if start <= codepoint <= end:
            return True

    return False


def tracked_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        if result.stderr:
            sys.stderr.buffer.write(result.stderr)
        raise SystemExit(result.returncode)

    files: list[Path] = []
    for raw_path in result.stdout.split(b"\x00"):
        if not raw_path:
            continue
        files.append(Path(raw_path.decode("utf-8", errors="surrogateescape")))
    return files


def main() -> int:
    found_any = False
    match_count = 0
    scanned_count = 0
    skipped_count = 0

    for path in tracked_files():
        try:
            raw = path.read_bytes()
        except OSError:
            skipped_count += 1
            continue

        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            skipped_count += 1
            continue

        scanned_count += 1
        line = 1
        col = 1
        for char in text:
            codepoint = ord(char)
            if is_target_codepoint(codepoint):
                name = unicodedata.name(char, "UNKNOWN")
                print(f"{path}:{line}:{col}: U+{codepoint:04X} {name}")
                found_any = True
                match_count += 1

            if char == "\n":
                line += 1
                col = 1
            else:
                col += 1

    print(
        "scanned(tracked utf-8): "
        f"{scanned_count}, skipped(binary/non-utf8): {skipped_count}, matches: {match_count}"
    )

    return 1 if found_any else 0


if __name__ == "__main__":
    raise SystemExit(main())
