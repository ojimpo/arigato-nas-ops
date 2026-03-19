#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <url>"
  exit 1
fi

URL="$1"
METUBE_BASE="${METUBE_BASE:-http://127.0.0.1:8081}"

payload="$(python3 -c 'import json,sys; print(json.dumps({
  "url": sys.argv[1],
  "quality": "best",
  "format": "mp4",
  "folder": "stash",
  "playlist_strict_mode": False,
  "auto_start": True
}))' "$URL")"

curl -sS -X POST \
  -H "Content-Type: application/json" \
  --data "$payload" \
  "$METUBE_BASE/add"
