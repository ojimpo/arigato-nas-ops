#!/usr/bin/env bash
set -euo pipefail
INCOMING=/mnt/media/audio/_incoming
DEV=${1:-/dev/sr0}
META="$INCOMING/current_cd_meta_${DEV##*/}.json"
[ -f "$META" ] || { echo "missing $META (run cd_meta.py --device $DEV first)"; exit 1; }
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
RUN_DIR="$INCOMING/rip_${STAMP}_${DEV##*/}"
mkdir -p "$RUN_DIR"
cp "$META" "$RUN_DIR/meta.json"
cd "$RUN_DIR"
STARTED_EPOCH=$(date -u +%s)
ACTIVE_FILE="$INCOMING/active_rip_${DEV##*/}.json"
echo "{\"run_dir\":\"$RUN_DIR\",\"pid\":$$,\"started\":\"$STAMP\",\"started_epoch\":$STARTED_EPOCH}" > "$ACTIVE_FILE"
cd-paranoia -d "$DEV" -B -e > rip.log 2>&1
echo "$RUN_DIR"