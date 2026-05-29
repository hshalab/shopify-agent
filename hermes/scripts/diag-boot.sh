#!/usr/bin/env bash
# Boot-time diagnostic dump. Prints to stdout so dokploy logs capture it.
# Redacts secret values to "<set>"/"<empty>".
set +e

mask() { local v="$1"; [[ -z "$v" ]] && echo "<empty>" || echo "<set, len=${#v}>"; }

echo "=================== HERMES BOOT DIAG ==================="
echo "[date]              $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[hostname]          $(hostname)"
echo "[whoami]            $(whoami)"
echo "[pwd]               $(pwd)"

echo
echo "=== process env (relevant keys, redacted) ==="
for k in OPENROUTER_API_KEY TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USERS TELEGRAM_HOME_CHANNEL TELEGRAM_ADMIN_CHAT TELEGRAM_CLIENT_CHATS TELEGRAM_CLIENT_CHAT SHOPIFY_STORE SHOPIFY_CLIENT_ID SHOPIFY_CLIENT_SECRET; do
  v="${!k}"
  echo "  $k = $(mask "$v")"
done

echo
echo "=== /opt/data layout ==="
ls -la /opt/data 2>&1 | head -40

echo
echo "=== /opt/data/.env ==="
if [[ -f /opt/data/.env ]]; then
  echo "EXISTS at /opt/data/.env"
  echo "  size: $(stat -c %s /opt/data/.env 2>/dev/null) bytes"
  echo "  perms: $(stat -c %a /opt/data/.env 2>/dev/null)"
  echo "  keys present:"
  grep -E '^[A-Z][A-Z0-9_]*=' /opt/data/.env | sed 's/=.*/= <redacted>/' | sed 's/^/    /'
else
  echo "MISSING at /opt/data/.env"
fi

echo
echo "=== /opt/data/logs ==="
ls -la /opt/data/logs 2>&1 | head -20

echo
echo "=== TAIL /opt/data/logs/agent.log (300 lines) ==="
tail -n 300 /opt/data/logs/agent.log 2>&1 | head -350

echo
echo "=== TAIL /opt/data/logs/errors.log (200 lines) ==="
tail -n 200 /opt/data/logs/errors.log 2>&1 | head -250

echo
echo "=== /opt/data/sessions count ==="
ls /opt/data/sessions 2>/dev/null | wc -l

echo
echo "=== /opt/data/state.db ==="
ls -la /opt/data/state.db* 2>&1 | head -5

echo
echo "=== /opt/data/cron ==="
ls -la /opt/data/cron 2>&1 | head -10

echo
echo "=== hermes config snippets ==="
grep -E '^(terminal|env_passthrough|providers|fallback|model)' /opt/data/config.yaml 2>/dev/null | head -20

echo
echo "=== /opt/data/.env content shape ==="
if [[ -f /opt/data/.env ]]; then
  echo "  total lines: $(wc -l < /opt/data/.env)"
  echo "  non-comment non-blank lines: $(grep -cvE '^\s*(#|$)' /opt/data/.env)"
  echo "  KEY=VAL lines (any indentation):"
  grep -nE '^\s*[A-Za-z_][A-Za-z0-9_]*=' /opt/data/.env | head -40 | sed -E 's/(=).*/\1<redacted>/' | sed 's/^/    /'
fi

echo
echo "=== test shopify-graphql.py env access (dry-run) ==="
python3 - <<'PY'
import os
keys = ["SHOPIFY_STORE","SHOPIFY_CLIENT_ID","SHOPIFY_CLIENT_SECRET","TELEGRAM_BOT_TOKEN","OPENROUTER_API_KEY"]
for k in keys:
    v = os.environ.get(k, "")
    print(f"  os.environ[{k}] = {('<set, len=%d>' % len(v)) if v else '<empty>'}")
PY

echo
echo "=== LIVE shopify-graphql.py call (productsCount) ==="
python3 /opt/data/scripts/shopify-graphql.py '{"query":"{ productsCount { count } }"}' 2>&1 | head -20 | sed -E 's/(X-Shopify-Access-Token[^,]*)/<redacted>/g' | sed -E 's/(access_token"\s*:\s*")[^"]+/\1<redacted>/g'

echo
echo "================= END HERMES BOOT DIAG ================="
