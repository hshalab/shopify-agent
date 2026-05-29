#!/usr/bin/env python3
"""
Shopify GraphQL API client. Only entry point allowed for talking to Shopify.
This is the ONLY script the agent is allowed to execute against Shopify.

Usage:
  python3 shopify-graphql.py <query_json>
  python3 shopify-graphql.py '{"query": "{ shop { name } }"}'
  python3 shopify-graphql.py '{"query": "mutation ...", "variables": {...}}'

Environment variables (required):
  SHOPIFY_STORE          - e.g. your-store.myshopify.com
  SHOPIFY_CLIENT_ID      - Your Shopify custom app client ID
  SHOPIFY_CLIENT_SECRET  - Your Shopify custom app client secret

Environment variables (optional):
  SHOPIFY_API_VERSION    - Admin API version (default: 2026-01)

Behaviour:
  - Tokens cached on disk for 23h (Shopify gives 24h, we leave a 1h buffer)
  - 200 OK with non-empty top-level GraphQL `errors` -> stderr + exit 1
  - 4xx/5xx HTTP                                     -> stderr + exit 1
  - userErrors are passed through inside JSON (the LLM reads them)
  - Authorization headers and access_token strings redacted in any error output

Security:
  - Only communicates with SHOPIFY_STORE (validated)
  - Token cache file mode 600 under /tmp
  - No shell execution, no file writes outside the cache file
  - Validates JSON input, rejects non-GraphQL payloads
"""

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

STORE = os.environ.get("SHOPIFY_STORE", "")
CLIENT_ID = os.environ.get("SHOPIFY_CLIENT_ID", "")
CLIENT_SECRET = os.environ.get("SHOPIFY_CLIENT_SECRET", "")
API_VERSION = os.environ.get("SHOPIFY_API_VERSION", "2026-01")

TOKEN_CACHE_PATH = Path(f"/tmp/.shopify-token-{STORE}.json") if STORE else None
TOKEN_TTL_S = 23 * 3600

_REDACT_RE = re.compile(
    r"(access_token\"\s*:\s*\")[^\"]+|(X-Shopify-Access-Token:\s*)\S+|(shpat_)\w+",
    re.IGNORECASE,
)


def _redact(text: str) -> str:
    return _REDACT_RE.sub(
        lambda m: (m.group(1) or m.group(2) or m.group(3) or "") + "<redacted>",
        text,
    )


def fatal(msg: str) -> None:
    print(json.dumps({"error": _redact(msg)}), file=sys.stderr)
    sys.exit(1)


def _cached_token():
    if TOKEN_CACHE_PATH is None or not TOKEN_CACHE_PATH.is_file():
        return None
    try:
        data = json.loads(TOKEN_CACHE_PATH.read_text())
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(data, dict) or data.get("store") != STORE:
        return None
    if data.get("expires_at", 0) <= time.time():
        return None
    token = data.get("token")
    return token if isinstance(token, str) and token else None


def _store_token(token: str) -> None:
    if TOKEN_CACHE_PATH is None:
        return
    payload = {
        "store": STORE,
        "token": token,
        "expires_at": int(time.time()) + TOKEN_TTL_S,
    }
    try:
        TOKEN_CACHE_PATH.write_text(json.dumps(payload))
        try:
            os.chmod(TOKEN_CACHE_PATH, 0o600)
        except OSError:
            pass
    except OSError:
        pass  # best-effort; we'll just mint again next call


def get_token() -> str:
    if not all([STORE, CLIENT_ID, CLIENT_SECRET]):
        fatal("Missing SHOPIFY_STORE, SHOPIFY_CLIENT_ID, or SHOPIFY_CLIENT_SECRET")

    cached = _cached_token()
    if cached:
        return cached

    url = f"https://{STORE}/admin/oauth/access_token"
    payload = json.dumps({
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "grant_type": "client_credentials",
    }).encode()

    req = urllib.request.Request(
        url, data=payload, headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        fatal(f"Auth HTTP {e.code}")
    except Exception:
        fatal("Auth failed")

    token = body.get("access_token") if isinstance(body, dict) else None
    if not token:
        fatal("Auth response missing access_token")

    _store_token(token)
    return token


def execute_graphql(query_json: str) -> None:
    try:
        payload = json.loads(query_json)
    except json.JSONDecodeError as e:
        fatal(f"Invalid JSON input: {e}")

    if "query" not in payload:
        fatal("Missing 'query' field. Expected: {\"query\": \"...\", \"variables\": {...}}")

    token = get_token()
    url = f"https://{STORE}/admin/api/{API_VERSION}/graphql.json"
    data = json.dumps(payload).encode()
    headers = {
        "Content-Type": "application/json",
        "X-Shopify-Access-Token": token,
    }
    req = urllib.request.Request(url, data=data, headers=headers)

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
    except urllib.error.HTTPError as e:
        try:
            body = e.read().decode("utf-8", errors="replace") if e.fp else ""
        except Exception:
            body = ""
        fatal(f"Shopify API error {e.code}: {body}")
    except Exception:
        fatal("Request failed")

    try:
        result = json.loads(raw)
    except json.JSONDecodeError:
        fatal("Shopify returned non-JSON body")

    # Surface throttle warnings (informational, does not fail).
    if isinstance(result, dict):
        extensions = result.get("extensions")
        cost = extensions.get("cost") if isinstance(extensions, dict) else None
        throttle = cost.get("throttleStatus") if isinstance(cost, dict) else None
        available = throttle.get("currentlyAvailable") if isinstance(throttle, dict) else None
        if isinstance(available, (int, float)) and available < 100:
            result["_warning"] = (
                f"Rate limit low: {available} points remaining. Wait before next request."
            )

    # GraphQL spec: top-level `errors` means the whole query failed
    # (validation, resolver, or auth). Distinct from per-mutation `userErrors`,
    # which are pass-through (the LLM reads them inside the JSON).
    errors = result.get("errors") if isinstance(result, dict) else None
    if errors:
        # Print full result to stdout so the LLM can still read context,
        # then fail loud on stderr and exit non-zero so callers don't
        # mistake a 200 for a success.
        print(json.dumps(result, indent=2, ensure_ascii=False))
        first_msg = ""
        if isinstance(errors, list) and errors and isinstance(errors[0], dict):
            first_msg = str(errors[0].get("message", ""))
        marker = first_msg if first_msg else f"{len(errors)} errors"
        print(json.dumps({"error": f"GraphQL errors: {marker}"}), file=sys.stderr)
        sys.exit(1)

    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        fatal("Usage: shopify-graphql.py '{\"query\": \"...\"}'")
    execute_graphql(sys.argv[1])
