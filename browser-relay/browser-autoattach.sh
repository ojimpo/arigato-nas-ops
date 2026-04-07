#!/bin/bash
# Auto-attach OpenClaw Chrome extension via template matching + xdotool click.
# Finds the extension icon in a screenshot, clicks it, then verifies.
#
# Required env: BROWSER_RELAY_WEBHOOK, OPENCLAW_RELAY_TOKEN, OPENCLAW_CDP_PORT, DISPLAY
# Required files: icon-template.png (in same directory as this script)
# Required packages: xdotool, xwd, python3, opencv-python-headless, websocket-client

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ICON_TEMPLATE="${SCRIPT_DIR}/icon-template.png"
COORD_CACHE="/tmp/openclaw-extension-icon-coords.txt"
CDP_PORT="${OPENCLAW_CDP_PORT:-18800}"
RELAY_PORT="${OPENCLAW_RELAY_PORT:-18792}"

# Wait for Chrome window to appear on DISPLAY
for i in $(seq 1 10); do
  if DISPLAY="${DISPLAY:-:10}" xdotool search --class "chrome" > /dev/null 2>&1; then
    echo "Chrome window found on attempt $i"
    sleep 3
    break
  fi
  echo "Waiting for Chrome window... (attempt $i/10)"
  sleep 3
done

# Find icon via template matching, falling back to cached coords
COORDS=$(python3 << PYEOF
import struct, numpy as np, cv2, subprocess, sys, os

TEMPLATE_PATH = "${ICON_TEMPLATE}"
COORD_CACHE = "${COORD_CACHE}"
THRESHOLD = 0.8

template = cv2.imread(TEMPLATE_PATH)
if template is None:
    print("FAIL:template not found", file=sys.stderr)
    sys.exit(1)

# Take screenshot
subprocess.run(['xwd', '-root', '-out', '/tmp/screen.xwd'],
    env={'DISPLAY': os.environ.get('DISPLAY', ':10')}, check=True)

with open('/tmp/screen.xwd', 'rb') as f:
    data = f.read()

header_size = struct.unpack('>I', data[:4])[0]
ncolors = struct.unpack('>I', data[76:80])[0]
pixel_offset = header_size + ncolors * 12
width = struct.unpack('>I', data[16:20])[0]
height = struct.unpack('>I', data[20:24])[0]

pixel_data = data[pixel_offset:]
raw = np.frombuffer(pixel_data, dtype=np.uint8).reshape(height, width, 4)
img = raw[:, :, :3]

result = cv2.matchTemplate(img, template, cv2.TM_CCOEFF_NORMED)
_, max_val, _, max_loc = cv2.minMaxLoc(result)

th, tw = template.shape[:2]
cx = max_loc[0] + tw // 2
cy = max_loc[1] + th // 2

if max_val >= THRESHOLD:
    with open(COORD_CACHE, 'w') as f:
        f.write(f"{cx} {cy}")
    print(f"{cx} {cy}")
else:
    try:
        with open(COORD_CACHE) as f:
            cached = f.read().strip()
        print(f"WARN:match too low ({max_val:.2f}), using cached {cached}", file=sys.stderr)
        print(cached)
    except:
        print(f"FAIL:match too low ({max_val:.2f}), no cache", file=sys.stderr)
        sys.exit(1)
PYEOF
)

if [ $? -ne 0 ] || [ -z "$COORDS" ]; then
  MSG="⚠️ **browser-relay**: 拡張アイコン検出失敗（テンプレートマッチング失敗）"
  curl -s -X POST "$BROWSER_RELAY_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"$MSG\"}" > /dev/null
  exit 1
fi

X=$(echo "$COORDS" | awk '{print $1}')
Y=$(echo "$COORDS" | awk '{print $2}')
echo "Clicking extension icon at ($X, $Y)"
DISPLAY="${DISPLAY:-:10}" xdotool mousemove "$X" "$Y" click 1

# Verify attachment
sleep 5
TABS=$(curl -s "http://127.0.0.1:${RELAY_PORT}/json" \
  -H "x-openclaw-relay-token: $OPENCLAW_RELAY_TOKEN")

if echo "$TABS" | python3 -c "import sys,json; tabs=json.load(sys.stdin); exit(0 if len(tabs)>0 else 1)" 2>/dev/null; then
  MSG="✅ **browser-relay**: Chrome起動・最大化・拡張アタッチ完了 (icon@${X},${Y})"
  curl -s -X POST "$BROWSER_RELAY_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"$MSG\"}" > /dev/null
else
  MSG="⚠️ **browser-relay**: 拡張アタッチ失敗（アイコンクリック@${X},${Y}したがタブ未登録）"
  curl -s -X POST "$BROWSER_RELAY_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"$MSG\"}" > /dev/null
  exit 1
fi
