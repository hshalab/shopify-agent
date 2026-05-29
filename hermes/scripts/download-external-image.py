#!/usr/bin/env python3
"""
Download an external image into the /tmp sandbox.

Usage:
  python3 download-external-image.py <https-url> <output_path>

Constraints:
  - Source host must be in ALLOWED_HOSTS (HTTPS only).
  - output_path is resolved and must sit under /tmp.
  - Body is streamed in chunks and capped at MAX_BYTES.
  - Content-Type must start with "image/".

Configuration:
  - ALLOWED_HOSTS is parsed at import time from the env var
    `IMAGE_DOWNLOAD_ALLOWED_HOSTS` (comma-separated list of hostnames).
    If unset or empty, the allowlist is empty and every download is
    rejected (fail closed).
"""

from __future__ import annotations

import json
import os
import sys
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

ALLOWED_HOSTS = {
    h.strip()
    for h in os.environ.get("IMAGE_DOWNLOAD_ALLOWED_HOSTS", "").split(",")
    if h.strip()
}
MAX_BYTES = 20 * 1024 * 1024
CHUNK_BYTES = 64 * 1024
SANDBOX_ROOT = Path("/tmp")


def fatal(message: str) -> int:
    print(json.dumps({"error": message}), file=sys.stderr)
    return 1


def _resolve_under_sandbox(p: Path) -> Path | None:
    """Resolve `p` and return it only if the resolved path is under SANDBOX_ROOT.

    Defends against `../` traversal and symlink chains pointing outside /tmp.
    """
    try:
        resolved = p.expanduser().resolve(strict=False)
        sandbox = SANDBOX_ROOT.resolve()
    except (OSError, RuntimeError):
        return None
    try:
        resolved.relative_to(sandbox)
    except ValueError:
        return None
    return resolved


def main() -> int:
    if len(sys.argv) != 3:
        return fatal("Usage: download-external-image.py <url> <output_path>")

    source_url = sys.argv[1]
    output_path = _resolve_under_sandbox(Path(sys.argv[2]))
    if output_path is None:
        return fatal("output_path must resolve under /tmp")

    parsed = urlparse(source_url)
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS:
        return fatal("Blocked source host")

    output_path.parent.mkdir(parents=True, exist_ok=True)

    request = urllib.request.Request(source_url, method="GET")

    total = 0
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            content_type = response.headers.get("Content-Type", "")
            if not content_type.startswith("image/"):
                return fatal("Unexpected content type")

            with output_path.open("wb") as fh:
                while True:
                    chunk = response.read(CHUNK_BYTES)
                    if not chunk:
                        break
                    total += len(chunk)
                    if total > MAX_BYTES:
                        try:
                            output_path.unlink(missing_ok=True)
                        except OSError:
                            pass
                        return fatal("Image too large")
                    fh.write(chunk)
    except Exception as exc:
        # Generic error class only — never echo source_url back.
        return fatal(f"Download failed: {type(exc).__name__}")

    print(json.dumps({"ok": True, "path": str(output_path), "bytes": total}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
