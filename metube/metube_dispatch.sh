#!/usr/bin/env bash
set -euo pipefail

# ---- Paths ----
SRC="/mnt/media/downloads/metube"
STASH_IN="$SRC/stash"
STASH_ROOT="/mnt/media/stash"

# ---- Env files ----
DISCORD_ENV="$HOME/.config/discord-metube-dispatch.env"  # DISCORD_WEBHOOK_URL=...
STASH_ENV="$HOME/.config/stash.env"                      # STASH_URL, STASH_APIKEY, STASH_SCAN_PATH

VIDEO_EXT_REGEX='.*\.(mp4|mkv|avi|mov|wmv|webm)$'
SCAN_COOLDOWN=1800

RUNLOG="$(mktemp)"
RUNLOG_MSG="${RUNLOG}.msg"
cleanup() { rm -f "$RUNLOG" "$RUNLOG_MSG"; }
trap cleanup EXIT

mkdir -p "$STASH_IN" "$STASH_ROOT/FC2" "$STASH_ROOT/JAV" "$STASH_ROOT/Uncensored" "$STASH_ROOT/Unsorted"

DISCORD_WEBHOOK_URL=""
if [ -f "$DISCORD_ENV" ]; then
  # shellcheck disable=SC1090
  source "$DISCORD_ENV"
  DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
fi

STASH_URL=""
STASH_APIKEY=""
STASH_SCAN_PATH="$STASH_ROOT"
if [ -f "$STASH_ENV" ]; then
  # shellcheck disable=SC1090
  source "$STASH_ENV"
  STASH_URL="${STASH_URL:-}"
  STASH_APIKEY="${STASH_APIKEY:-}"
  STASH_SCAN_PATH="${STASH_SCAN_PATH:-$STASH_DST}"
fi

is_video() {
  local f="$1"
  case "$f" in
    *.part|*.tmp|*.crdownload) return 1 ;;
  esac
  [[ "$f" =~ $VIDEO_EXT_REGEX ]]
}

derive_stash_base() {
  local base="$1"
  local name ext
  name="${base%.*}"
  ext="${base##*.}"

  # Uncensored系は元の先頭識別子を維持（1Pondo / Caribbean / Heyzo など）
  if [[ "$name" =~ ^(1Pondo|Caribbeancom|CaribbeanPR|Heyzo|Heydouga)- ]]; then
    printf "%s" "$base"
    return 0
  fi

  # FC2-PPV-4825382 / FC2 PPV 4825382 / FC2_PPV_4825382 -> FC2-PPV-4825382
  if [[ "$name" =~ [Ff][Cc]2[-_[:space:]]*[Pp][Pp][Vv][-_[:space:]]*([0-9]{3,}) ]]; then
    printf "FC2-PPV-%s.%s" "${BASH_REMATCH[1]}" "$ext"
    return 0
  fi

  # SOE-396 など
  if [[ "$name" =~ ([A-Za-z]{2,8})-([0-9]{2,7}) ]]; then
    printf "%s-%s.%s" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$ext"
    return 0
  fi

  printf "%s" "$base"
}

route_stash_dir() {
  local filename="$1"

  if [[ "$filename" =~ ^FC2-PPV-[0-9]+ ]]; then
    printf "%s" "$STASH_ROOT/FC2"
    return 0
  fi

  if [[ "$filename" =~ ^(1Pondo|Caribbeancom|CaribbeanPR|Heyzo|Heydouga)- ]]; then
    printf "%s" "$STASH_ROOT/Uncensored"
    return 0
  fi

  if [[ "$filename" =~ ^[A-Za-z]{2,8}-[0-9]{2,7} ]]; then
    printf "%s" "$STASH_ROOT/JAV"
    return 0
  fi

  printf "%s" "$STASH_ROOT/Unsorted"
}

move_one() {
  local src="$1"
  local base target_base dst_dir
  base="$(basename "$src")"
  target_base="$(derive_stash_base "$base")"
  dst_dir="$(route_stash_dir "$target_base")"

  if mv -n "$src" "$dst_dir/$target_base"; then
    # 通知にはリネーム後の安全な表示名のみ残す
    printf "Stash\t%s\t%s\n" "$(basename "$dst_dir")" "$target_base" >> "$RUNLOG"
  fi
}

dispatch_stash() {
  while IFS= read -r f; do
    if is_video "$f"; then
      move_one "$f"
    fi
  done < <(find "$STASH_IN" -maxdepth 1 -type f -print)
}

send_discord() {
  local text="$1"
  [ -n "$DISCORD_WEBHOOK_URL" ] || return 0

  local max=1900
  while [ "${#text}" -gt "$max" ]; do
    local chunk="${text:0:$max}"
    text="${text:$max}"
    curl -sS -H "Content-Type: application/json" \
      -d "$(python3 -c 'import json,sys; print(json.dumps({"content": sys.argv[1]}))' "$chunk")" \
      "$DISCORD_WEBHOOK_URL" >/dev/null
  done

  curl -sS -H "Content-Type: application/json" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"content": sys.argv[1]}))' "$text")" \
    "$DISCORD_WEBHOOK_URL" >/dev/null
}

stash_scan() {
  if [ -z "${STASH_URL:-}" ] || [ -z "${STASH_APIKEY:-}" ] || [ -z "${STASH_SCAN_PATH:-}" ]; then
    echo "disabled"
    return 0
  fi

  local stamp="/tmp/stash_scan_last"
  local now last remain
  now=$(date +%s)

  if [ -f "$stamp" ]; then
    last=$(cat "$stamp" 2>/dev/null || echo 0)
    remain=$((SCAN_COOLDOWN - (now - last)))
    if [ "$remain" -gt 0 ]; then
      echo "skipped:$(((remain + 59) / 60))m"
      return 0
    fi
  fi

  payload="$(python3 - <<'PY' "$RUNLOG" "$STASH_SCAN_PATH"
import json,sys
runlog=sys.argv[1]
default_path=sys.argv[2]
paths=[]
with open(runlog,'r',encoding='utf-8',errors='ignore') as f:
    for line in f:
        parts=line.rstrip('\n').split('\t')
        if len(parts) >= 3 and parts[0] == 'Stash':
            folder=parts[1]
            # Stash container sees /data/videos/... not /mnt/media/stash/...
            p=f"/data/videos/{folder}"
            if p not in paths:
                paths.append(p)
if not paths:
    paths=[default_path]
paths_arg=', '.join('"'+p.replace('"','\\"')+'"' for p in paths)
q=f"mutation {{ metadataScan(input: {{ paths: [{paths_arg}] }}) }}"
print(json.dumps({"query": q}))
PY
)"

  curl -sS -X POST \
    -H "ApiKey: ${STASH_APIKEY}" -H "Content-Type: application/json" \
    --data "$payload" \
    "$STASH_URL" >/dev/null || true

  echo "$now" > "$stamp"
  echo "started"
}

# ---- Dispatch ----
dispatch_stash

# nothing moved -> quiet
if [ ! -s "$RUNLOG" ]; then
  exit 0
fi

STASH_SCAN_STATUS="$(stash_scan)"

{
  echo "✅ MeTube dispatch 完了"
  echo
  echo "🔒 Stash dispatch"
  python3 - <<'PY' "$RUNLOG"
import sys
for line in open(sys.argv[1], encoding='utf-8', errors='ignore'):
    parts=line.rstrip('\n').split('\t')
    if len(parts) >= 3 and parts[0] == 'Stash':
        folder,name=parts[1],parts[2]
        print(f"- [{folder}] ||{name}||")
PY
  echo

  case "$STASH_SCAN_STATUS" in
    started)   echo "🔄 Stash scan started" ;;
    skipped:*) echo "⏭️ Stash scan skipped (${STASH_SCAN_STATUS#skipped:} cooldown)" ;;
    disabled)  echo "⚠️ Stash scan disabled (missing url/apikey/path)" ;;
  esac
} > "$RUNLOG_MSG"

send_discord "$(cat "$RUNLOG_MSG")"
