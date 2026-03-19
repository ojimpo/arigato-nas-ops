#!/usr/bin/env bash
set -euo pipefail

# Stash periodic scan only (no move, no Plex)
STASH_ENV="$HOME/.config/stash.env"
STASH_URL=""
STASH_APIKEY=""
STASH_SCAN_PATH="/mnt/media/stash/metube"

if [ -f "$STASH_ENV" ]; then
  # shellcheck disable=SC1090
  source "$STASH_ENV"
  STASH_URL="${STASH_URL:-}"
  STASH_APIKEY="${STASH_APIKEY:-}"
  STASH_SCAN_PATH="${STASH_SCAN_PATH:-/mnt/media/stash/metube}"
fi

if [ -n "${STASH_URL:-}" ] && [ -n "${STASH_APIKEY:-}" ] && [ -n "${STASH_SCAN_PATH:-}" ]; then
  payload="$(python3 -c '
import json,sys
p=sys.argv[1]
q=f"""mutation {{ metadataScan(input: {{ paths: [\"{p}\"] }}) }}"""
print(json.dumps({"query": q}))
' "$STASH_SCAN_PATH")"

  curl -sS -X POST \
    -H "ApiKey: ${STASH_APIKEY}" -H "Content-Type: application/json" \
    --data "$payload" \
    "$STASH_URL" >/dev/null || true
fi
