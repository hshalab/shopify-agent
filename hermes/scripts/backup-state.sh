#!/usr/bin/env bash
# Daily backup of the Hermes runtime volume (state.db + memories + cron + auth).
# Triggered by cron-backup. Outputs a tar.gz to /opt/data/backups/.
#
# Why this exists:
#   `hermes-data` is a Docker named volume. `docker compose down -v` or a
#   Dokploy garbage-collect wipes it permanently — sessions, memories, cron,
#   auth.json, all gone. This snapshot makes recovery a single `tar -xzf` away.
#
# What is NOT in the snapshot:
#   - logs/ (rotates fast, low recovery value)
#   - skills/, sandboxes/, .cache/, models_dev_cache.json (regenerable on boot)
#   - .env (lives outside the volume, never in the snapshot)

set -uo pipefail

DATA_DIR="${HERMES_DATA_DIR:-/opt/data}"
BACKUP_DIR="${BACKUP_DIR:-${DATA_DIR}/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

TS="$(date -u +%Y%m%d-%H%M%S)"
ARCHIVE="${BACKUP_DIR}/hermes-${TS}.tgz"
STDERR_TMP="$(mktemp -t hermes-backup-XXXXXX.err)"
trap 'rm -f "$STDERR_TMP"' EXIT

mkdir -p "$BACKUP_DIR"

# Items to include if they exist. Missing items are skipped silently — first
# boot may not have created all of them yet.
declare -a TARGETS=(
  "state.db"
  "memories"
  "cron"
  "auth.json"
  "channel_directory.json"
  "gateway_state.json"
)

declare -a EXISTING=()
for t in "${TARGETS[@]}"; do
  if [[ -e "${DATA_DIR}/${t}" ]]; then
    EXISTING+=("$t")
  fi
done

if [[ "${#EXISTING[@]}" -eq 0 ]]; then
  echo "BACKUP_SKIPPED: no targets to back up under ${DATA_DIR}"
  exit 0
fi

if ! tar -czf "$ARCHIVE" -C "$DATA_DIR" "${EXISTING[@]}" 2>"$STDERR_TMP"; then
  echo "BACKUP_FAILED: tar exited non-zero"
  cat "$STDERR_TMP" >&2
  exit 1
fi

# Quick integrity probe — verify tar can re-list the archive contents.
if ! tar -tzf "$ARCHIVE" >/dev/null 2>&1; then
  echo "BACKUP_FAILED: archive verify failed for $ARCHIVE"
  rm -f "$ARCHIVE"
  exit 1
fi

SIZE_BYTES="$(stat -c %s "$ARCHIVE" 2>/dev/null || stat -f %z "$ARCHIVE" 2>/dev/null || echo 0)"

# Retention: drop archives older than RETENTION_DAYS days.
PRUNED="$(find "$BACKUP_DIR" -maxdepth 1 -name 'hermes-*.tgz' -type f -mtime "+${RETENTION_DAYS}" -print -delete 2>/dev/null | wc -l | tr -d ' ')"

echo "BACKUP_OK: ${ARCHIVE} (${SIZE_BYTES} bytes, pruned ${PRUNED} old archive(s))"
