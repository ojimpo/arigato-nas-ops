#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/var/log/backup-jobs"
mkdir -p "$LOG_DIR"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
HOST="$(hostname -s)"
LOG_FILE="$LOG_DIR/restic-check-${STAMP}.log"

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
  msg=$(printf '❌ restic check FAILED (%s) exit=%s\nlog: %s' "$HOST" "$code" "$LOG_FILE")
  post_discord "$msg"
  echo "$msg"
  exit "$code"
}
trap on_error ERR

{
  echo "==== restic check start (UTC) $(date -u '+%F %T') host=${HOST} ===="
  export RESTIC_REPOSITORY="/mnt/media/.system-backups/arigato-nas/restic"
  export RESTIC_PASSWORD_FILE="/home/kouki/.config/restic/arigato-nas-passphrase"
  /home/kouki/.local/bin/restic check --read-data-subset=2.5%
  echo "==== restic check end (UTC) $(date -u '+%F %T') ===="
} >"$LOG_FILE" 2>&1

SUMMARY=$(printf '🩺 restic check success (%s)\nlog: %s' "$HOST" "$LOG_FILE")
post_discord "$SUMMARY"
echo "$SUMMARY"
