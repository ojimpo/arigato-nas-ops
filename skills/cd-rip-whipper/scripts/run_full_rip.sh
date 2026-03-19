#!/usr/bin/env bash
set -euo pipefail
# Master script to run the entire rip and finalize process.
# This is intended to be run by a sub-agent.

# Load Discord webhook configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/cd_rip_webhook.sh" ]; then
  source "$SCRIPT_DIR/cd_rip_webhook.sh"
fi

DEV=${1:-/dev/sr0}
echo "[LOG] Starting rip process for $DEV..." >&2
/home/kouki/clawd/skills/cd-rip-whipper/scripts/start_rip.sh "$DEV" >&2

echo "[LOG] Rip finished for $DEV, starting finalization..." >&2
# Enable kashidashi matcher V2 by default (can be overridden per-run)
export KASHIDASHI_MATCH_V2="${KASHIDASHI_MATCH_V2:-1}"
export KASHIDASHI_DRY_RUN="${KASHIDASHI_DRY_RUN:-0}"
FINAL_JSON=$(/home/kouki/clawd/skills/cd-rip-whipper/scripts/finalize_rip.py "$DEV")

echo "[LOG] Finalization complete. Parsing result..." >&2
ELAPSED=$(echo "$FINAL_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('elapsed', '??:??'))")
ALBUM=$(echo "$FINAL_JSON" | python3 -c "import sys, json, pathlib; d=json.load(sys.stdin); print(pathlib.Path(d.get('dst','')).name or 'Unknown Album')")
KASHI=$(echo "$FINAL_JSON" | python3 -c "import sys, json; d=json.load(sys.stdin).get('kashidashi',{}); s=d.get('status','unknown'); mid=d.get('matched_item_id'); r=d.get('reason');
if s=='matched': print(f'kashidashi=matched(id={mid})')
elif s=='no_match': print('kashidashi=no_match')
elif s=='skipped': print(f'kashidashi=skipped({r or "reason"})')
elif s=='dry_run_match': print(f'kashidashi=dry_run(id={mid})')
elif s=='error': print('kashidashi=error')
else: print('kashidashi=unknown')")

# The final output of this script is what the user will see.
MSG="<@YOUR_DISCORD_USER_ID> リッピング完了：$ALBUM（経過 $ELAPSED / $KASHI）。ディスクをイジェクトする？"
echo "$MSG"

# Post completion notification via Discord webhook (if configured)
if [ -n "${CD_RIP_DISCORD_WEBHOOK_URL:-}" ]; then
  curl -s -X POST -H 'Content-Type: application/json' -d "{\"content\":\"$MSG\"}" "$CD_RIP_DISCORD_WEBHOOK_URL" || true
fi
