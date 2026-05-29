#!/usr/bin/env bash
set -euo pipefail

HERMES_BIN="${HERMES_BIN:-/opt/hermes/.venv/bin/hermes}"
WORKDIR="${HERMES_WORKDIR:-/opt/data}"

FALLBACK_CHAT="${TELEGRAM_HOME_CHANNEL:-}"
ADMIN_CHAT="${TELEGRAM_ADMIN_CHAT:-$FALLBACK_CHAT}"
CLIENT_CHAT_LIST="${TELEGRAM_CLIENT_CHATS:-${TELEGRAM_CLIENT_CHAT:-$FALLBACK_CHAT}}"

# Operator/owner the admin crons report to. Falls back to a neutral label so
# prompts never hardcode a person's name.
OWNER_NAME="${OWNER_NAME:-the store owner}"

if [[ -z "$ADMIN_CHAT" || -z "$CLIENT_CHAT_LIST" ]]; then
  echo "Set TELEGRAM_ADMIN_CHAT and TELEGRAM_CLIENT_CHATS/TELEGRAM_CLIENT_CHAT (or TELEGRAM_HOME_CHANNEL as fallback) before creating cron jobs." >&2
  exit 1
fi

ADMIN_DELIVER="telegram:${ADMIN_CHAT}"
CLIENT_DELIVERS=()
IFS=',' read -r -a CLIENT_CHATS <<< "$CLIENT_CHAT_LIST"
for chat in "${CLIENT_CHATS[@]}"; do
  chat="${chat//[[:space:]]/}"
  [[ -n "$chat" ]] || continue
  deliver="telegram:${chat}"
  if [[ " ${CLIENT_DELIVERS[*]} " != *" ${deliver} "* ]]; then
    CLIENT_DELIVERS+=("$deliver")
  fi
done

if [[ "${#CLIENT_DELIVERS[@]}" -eq 0 ]]; then
  echo "Set at least one client chat in TELEGRAM_CLIENT_CHATS/TELEGRAM_CLIENT_CHAT." >&2
  exit 1
fi

JOBS_FILE="${WORKDIR}/cron/jobs.json"
CANONICAL_NAMES="cron-engagement cron-seo-daily cron-report cron-monitor cron-backup cron-cleanup"

# `hermes cron create` has no upsert flag, so re-running this script appends
# duplicates. Remove any pre-existing canonical jobs by reading jobs.json
# directly (parsing `cron list` is fragile, and `cron remove` only takes IDs).
# Ad-hoc jobs with non-canonical names are preserved.
if [[ -f "$JOBS_FILE" ]]; then
  removed=0
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    ( cd "$WORKDIR" && "$HERMES_BIN" cron remove "$id" ) >/dev/null 2>&1 || true
    removed=$((removed + 1))
  done < <(JOBS_FILE="$JOBS_FILE" CANONICAL="$CANONICAL_NAMES" python3 - <<'PY'
import json, os
canonical = set(os.environ["CANONICAL"].split())
try:
    with open(os.environ["JOBS_FILE"]) as f:
        data = json.load(f)
except Exception:
    raise SystemExit(0)
jobs = data if isinstance(data, list) else data.get("jobs", [])
for job in jobs:
    if isinstance(job, dict) and job.get("name") in canonical:
        jid = job.get("id")
        if jid:
            print(jid)
PY
)
  if [[ "$removed" -gt 0 ]]; then
    echo "bootstrap-cron: removed $removed pre-existing canonical job(s)"
  fi
fi

create_job() {
  local schedule="$1"
  local name="$2"
  local deliver="$3"
  local prompt="$4"

  "$HERMES_BIN" cron create \
    --name "$name" \
    --deliver "$deliver" \
    --workdir "$WORKDIR" \
    "$schedule" \
    "$prompt"
}

create_client_job() {
  local schedule="$1"
  local name="$2"
  local prompt="$3"
  local deliver

  for deliver in "${CLIENT_DELIVERS[@]}"; do
    create_job "$schedule" "$name" "$deliver" "$prompt"
  done
}

create_client_job "0 9 * * 1-5" "cron-engagement" \
"Query real Shopify data and send a single short, smart good-morning message. Pick only the most useful insight of the day: a recent sale, an out-of-stock product that was selling, a clear opportunity, or a healthy status. Follow SOUL.md, AGENTS.md and TOOLS.md. Do not invent data. Do not mix topics. Respond in the store's configured language, defaulting to English."

create_client_job "30 9 * * 1-5" "cron-seo-daily" \
"Make the daily micro-improvement based on the day of the week: Monday descriptions, Tuesday photos, Wednesday SEO, Thursday suspicious pricing, Friday drafts. Query real Shopify data, pick a single product or finding, and end with an actionable question. Do not make any changes without the user's confirmation. Respond in the store's configured language, defaulting to English."

create_client_job "15 9 * * 1" "cron-report" \
"Generate the smart weekly report. Query real orders, products, stock and SEO. Adapt the tone to sales volume: 0, 1-5 or 6+. Keep it mobile-friendly, short and actionable. Do not perform any mutations. Respond in the store's configured language, defaulting to English."

create_job "0 10 * * *" "cron-monitor" "$ADMIN_DELIVER" \
"Check system health: Shopify connectivity with a minimal query, overall gateway status, and availability of the required credentials. Report only to ${OWNER_NAME} with a short summary. Do not expose secrets."

create_job "50 3 * * *" "cron-backup" "$ADMIN_DELIVER" \
"Run /opt/data/scripts/backup-state.sh and briefly report to ${OWNER_NAME} the name and size of the created archive. If it fails, report it. Do not expose secrets or internal paths beyond the backup file name."

create_job "55 3 * * *" "cron-cleanup" "$ADMIN_DELIVER" \
"Run the cleanup of old memory/logs using /opt/data/scripts/cleanup-memory.py if applicable. Report the result briefly. Do not delete source files or configuration."
