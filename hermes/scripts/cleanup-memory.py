#!/usr/bin/env python3

from __future__ import annotations

from datetime import date, timedelta
from pathlib import Path
import re
import sys


MEMORY_DIR = Path("/opt/data/memories")
DATE_PREFIX = re.compile(r"^(\d{4}-\d{2}-\d{2}).*\.md$")


def main() -> int:
    keep_days = int(sys.argv[1]) if len(sys.argv) > 1 else 5
    cutoff = date.today() - timedelta(days=keep_days)
    deleted = 0

    try:
        if not MEMORY_DIR.is_dir():
            print("CLEANUP_DONE: nothing to clean")
            return 0
    except OSError as exc:
        print(
            f"CLEANUP_FAILED: cannot access {MEMORY_DIR}: {type(exc).__name__}",
            file=sys.stderr,
        )
        return 1

    for path in MEMORY_DIR.iterdir():
        if path.name == ".gitkeep" or not path.is_file():
            continue

        match = DATE_PREFIX.match(path.name)
        if not match:
            continue

        file_date = date.fromisoformat(match.group(1))
        if file_date < cutoff:
            path.unlink(missing_ok=True)
            deleted += 1

    if deleted == 0:
        print("CLEANUP_DONE: nothing to clean")
    else:
        print(f"CLEANUP_DONE: {deleted} files deleted")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
