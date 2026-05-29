#!/usr/bin/env bash
# Boot wrapper for Hermes gateway.
#
# Architecture:
#   - /opt/init  — read-only bind mount of repo's ./hermes (source brain).
#   - /opt/data  — Docker named volume `hermes-data` (persistent runtime
#     state: sessions, memories, state.db, cron, logs, etc.).
#
# On boot we sync source brain files from /opt/init into /opt/data. Runtime
# state in /opt/data is preserved across container restarts and dokploy
# redeploys. Only an explicit `docker volume rm` destroys it.

set -euo pipefail

# Source brain — single files copied from /opt/init to /opt/data on each boot.
# USER.md is intentionally excluded: it is seeded from USER.md.example only on
# first boot so operator edits in /opt/data/USER.md survive subsequent boots.
SOURCE_FILES=(config.yaml AGENTS.md SOUL.md IDENTITY.md HEARTBEAT.md TOOLS.md)
# Source brain — directories whose CONTENT is mirrored from /opt/init to /opt/data
# (the destination dir is preserved; only files inside are overwritten).
SOURCE_DIRS=(scripts tools)
# Runtime dirs — Hermes writes here. Created if missing, never wiped.
RUNTIME_DIRS=(cron logs sessions memories plans home hooks skins skills workspace)

ensure_runtime_dirs() {
  for d in "${RUNTIME_DIRS[@]}"; do
    mkdir -p "/opt/data/$d" 2>/dev/null || true
  done
}

# Hermes runtime loads `/opt/data/.env` (cwd-relative) instead of the
# container process env, so a stale .env in the named volume survives
# credential rotations done via compose `env_file`. Regenerate it from the
# current process env on every boot using an allowlist.
ENV_ALLOWLIST=(
  OPENROUTER_API_KEY
  OPENCODE_GO_API_KEY
  HERMES_IMAGE
  HERMES_MAX_ITERATIONS
  HERMES_DIAG
  AGENT_NAME
  OWNER_NAME
  CLIENT_NAME
  STORE_NAME
  LOCALE
  TELEGRAM_BOT_TOKEN
  TELEGRAM_ALLOWED_USERS
  TELEGRAM_ADMIN_CHAT
  TELEGRAM_CLIENT_CHATS
  TELEGRAM_CLIENT_CHAT
  TELEGRAM_HOME_CHANNEL
  TELEGRAM_HOME_CHANNEL_NAME
  SHOPIFY_STORE
  SHOPIFY_CLIENT_ID
  SHOPIFY_CLIENT_SECRET
  SHOPIFY_API_VERSION
  BLOG_ID
  ONLINE_STORE_PUBLICATION_ID
  THEME_ID
  DOKPLOY_API_KEY
)

sync_env_to_volume() {
  local target=/opt/data/.env
  local tmp="$target.tmp"
  local written=0
  : > "$tmp"
  for v in "${ENV_ALLOWLIST[@]}"; do
    if [ -n "${!v-}" ]; then
      local val="${!v}"
      local escaped="${val//\'/\'\\\'\'}"
      printf "%s='%s'\n" "$v" "$escaped" >> "$tmp"
      written=$((written + 1))
    fi
  done
  mv -f "$tmp" "$target"
  chmod 600 "$target" 2>/dev/null || true
  echo "start-gateway: synced $written allowlisted env var(s) to $target"
}

sync_source_brain() {
  for f in "${SOURCE_FILES[@]}"; do
    if [ -f "/opt/init/$f" ]; then
      cp -f "/opt/init/$f" "/opt/data/$f"
    fi
  done
  for d in "${SOURCE_DIRS[@]}"; do
    if [ -d "/opt/init/$d" ]; then
      mkdir -p "/opt/data/$d"
      # Mirror /opt/init/$d/* into /opt/data/$d/ — overwrites source files,
      # leaves any other files in /opt/data/$d untouched.
      cp -fr "/opt/init/$d/." "/opt/data/$d/"
    fi
  done
  # Seed USER.md from template only on first boot — preserve operator edits afterward.
  if [ ! -f /opt/data/USER.md ] && [ -f /opt/init/USER.md.example ]; then
    cp /opt/init/USER.md.example /opt/data/USER.md
    echo "start-gateway: seeded /opt/data/USER.md from template"
  fi
}

if [ ! -f /opt/data/.brain_initialized ]; then
  echo "start-gateway: first boot — initializing /opt/data from /opt/init"
  if cp -r /opt/init/. /opt/data/; then
    touch /opt/data/.brain_initialized
    echo "start-gateway: /opt/data initialized"
  else
    echo "start-gateway: ERROR first-boot init failed; will retry on next start"
    exit 1
  fi
else
  echo "start-gateway: subsequent boot — syncing source brain only"
  sync_source_brain
fi

ensure_runtime_dirs
sync_env_to_volume

echo "start-gateway: running bootstrap-cron"
bash /opt/data/scripts/bootstrap-cron.sh || echo "start-gateway: bootstrap-cron exited with errors (continuing)"

ensure_runtime_dirs

# Optional boot-time diagnostics — set HERMES_DIAG=1 in env to opt in
if [ "${HERMES_DIAG:-0}" = "1" ] && [ -f /opt/data/scripts/diag-boot.sh ]; then
  echo "start-gateway: running diag-boot (HERMES_DIAG=1)"
  bash /opt/data/scripts/diag-boot.sh || echo "start-gateway: diag-boot exited with errors (continuing)"
fi

echo "start-gateway: ====== prior agent.log (last 200 lines) ======"
tail -n 200 /opt/data/logs/agent.log 2>&1 | sed 's/^/[agent.log.prev] /' || echo "[no prior agent.log]"
echo "start-gateway: ====== prior errors.log (last 100 lines) ======"
tail -n 100 /opt/data/logs/errors.log 2>&1 | sed 's/^/[errors.log.prev] /' || echo "[no prior errors.log]"
echo "start-gateway: ====== end of prior logs ======"

# Mirror agent.log to stdout so dokploy logs API captures the gateway's
# runtime trace (inbound messages, tool calls, errors).
(
  while :; do
    until [ -f /opt/data/logs/agent.log ]; do sleep 1; done
    # stdbuf -oL forces line-buffered output through the pipe; otherwise
    # sed block-buffers (4-8KB) and trace lines lag minutes before reaching
    # docker logs.
    stdbuf -oL tail -n 500 -F /opt/data/logs/agent.log 2>/dev/null \
      | stdbuf -oL sed 's/^/[agent.log] /'
    sleep 2
  done
) &
disown $! 2>/dev/null || true
echo "start-gateway: agent.log mirror running (pid=$!)"

echo "start-gateway: launching hermes gateway"
exec /opt/hermes/.venv/bin/hermes gateway run --accept-hooks
