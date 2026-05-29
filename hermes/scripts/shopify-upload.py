#!/usr/bin/env python3
"""
Upload a file to a Shopify staged upload URL (Step 2 of image pipeline).

Flow:
  1. Agent calls stagedUploadsCreate via shopify-graphql.py -> gets URL + params
  2. THIS SCRIPT posts the file to that staged URL (multipart/form-data)
  3. Agent calls productCreateMedia via shopify-graphql.py -> attaches to product

Usage:
  python3 shopify-upload.py <file_path> <staged_url> <parameters_json>

  file_path        - Local path to the image file
  staged_url       - URL from stagedTargets.url
  parameters_json  - JSON array from stagedTargets.parameters

Security:
  - Only POSTs to known Shopify staged upload domains
  - Stdlib only, no external dependencies
"""

import json
import os
import sys
import urllib.request
import urllib.error
import uuid
from urllib.parse import urlparse

ALLOWED_HOSTS = frozenset(
    [
        "shopify-staged-uploads.storage.googleapis.com",
        "storage.shopifycdn.com",
    ]
)


def fatal(msg):
    print(json.dumps({"error": msg}), file=sys.stderr)
    sys.exit(1)


def build_multipart(fields, file_path):
    boundary = f"----OC{uuid.uuid4().hex}"
    body = b""

    for field in fields:
        body += f"--{boundary}\r\n".encode()
        body += (
            f'Content-Disposition: form-data; name="{field["name"]}"\r\n\r\n'.encode()
        )
        body += f"{field['value']}\r\n".encode()

    content_type = "application/octet-stream"
    for f in fields:
        if f.get("name", "").lower() == "content-type":
            content_type = f["value"]
            break

    filename = os.path.basename(file_path)
    body += f"--{boundary}\r\n".encode()
    body += f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'.encode()
    body += f"Content-Type: {content_type}\r\n\r\n".encode()

    with open(file_path, "rb") as fh:
        body += fh.read()

    body += f"\r\n--{boundary}--\r\n".encode()
    return body, f"multipart/form-data; boundary={boundary}"


def main():
    if len(sys.argv) != 4:
        fatal("Usage: shopify-upload.py <file_path> <staged_url> <parameters_json>")

    file_path, staged_url, params_raw = sys.argv[1], sys.argv[2], sys.argv[3]

    if not os.path.isfile(file_path):
        fatal(f"File not found: {file_path}")

    parsed = urlparse(staged_url)
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS:
        fatal(f"Blocked: {parsed.hostname} is not an allowed Shopify upload host")

    try:
        params = json.loads(params_raw)
    except json.JSONDecodeError as e:
        fatal(f"Invalid parameters JSON: {e}")

    if not isinstance(params, list):
        fatal("Parameters must be a JSON array of {name, value} objects")

    body, ct = build_multipart(params, file_path)
    req = urllib.request.Request(
        staged_url, data=body, headers={"Content-Type": ct}, method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            print(json.dumps({"ok": True, "status": resp.getcode()}))
    except urllib.error.HTTPError as e:
        resp_body = e.read().decode("utf-8", errors="replace") if e.fp else ""
        fatal(f"Upload failed (HTTP {e.code}): {resp_body}")
    except Exception as e:
        fatal(f"Upload failed: {e}")


if __name__ == "__main__":
    main()
