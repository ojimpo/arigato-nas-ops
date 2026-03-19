#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/var/log/backup-jobs"
mkdir -p "$LOG_DIR"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
HOST="$(hostname -s)"
LOG_FILE="$LOG_DIR/backup-${STAMP}.log"

WEBHOOK_ENV="/etc/backup-discord-webhook.env"
if [[ -f "$WEBHOOK_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$WEBHOOK_ENV"
fi

post_discord() {
  local text="$1"
  [[ -n "${DISCORD_WEBHOOK_URL:-}" ]] || return 0
  command -v curl >/dev/null 2>&1 || return 0

  local payload
  payload=$(python3 - <<'PY' "$text"
import json,sys
print(json.dumps({"content": sys.argv[1]}))
PY
)

  curl -fsS -H 'Content-Type: application/json' -d "$payload" "$DISCORD_WEBHOOK_URL" >/dev/null || true
}

on_error() {
  local code=$?
  local msg
  msg=$(printf '❌ backup FAILED (%s) exit=%s\nlog: %s' "$HOST" "$code" "$LOG_FILE")
  post_discord "$msg"
  echo "$msg"
  exit "$code"
}
trap on_error ERR

{
  echo "==== backup start (UTC) $(date -u '+%F %T') host=${HOST} ===="
  /home/kouki/bin/backup-ssd-to-hdd1.sh
  echo "==== backup end (UTC) $(date -u '+%F %T') ===="
} >"$LOG_FILE" 2>&1

# summary
SNAPSHOT_LINE="$(grep -E 'snapshot [0-9a-f]+ saved' "$LOG_FILE" | tail -n 1 || true)"
ADDED_LINE="$(grep -E '^Added to the repository:' "$LOG_FILE" | tail -n 1 || true)"
PROC_LINE="$(grep -E '^processed [0-9]+' "$LOG_FILE" | tail -n 1 || true)"

SUMMARY=$(printf '✅ backup success (%s)\n%s\n%s\n%s\nlog: %s' "$HOST" "$SNAPSHOT_LINE" "$ADDED_LINE" "$PROC_LINE" "$LOG_FILE")
post_discord "$SUMMARY"

echo "$SUMMARY"
