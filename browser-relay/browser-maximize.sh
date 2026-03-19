#!/bin/bash
# Maximize OpenClaw Chrome window via CDP after browser start.
# Required env: BROWSER_RELAY_WEBHOOK, OPENCLAW_CDP_PORT, DISPLAY

CDP_PORT="${OPENCLAW_CDP_PORT:-18800}"

sleep 2
python3 -c "
import json, websocket, urllib.request
targets = json.loads(urllib.request.urlopen('http://127.0.0.1:${CDP_PORT}/json').read())
page = next(t for t in targets if t['type'] == 'page')
ws = websocket.create_connection(page['webSocketDebuggerUrl'], suppress_origin=True)
ws.send(json.dumps({'id': 1, 'method': 'Browser.getWindowForTarget'}))
wid = json.loads(ws.recv())['result']['windowId']
ws.send(json.dumps({'id': 2, 'method': 'Browser.setWindowBounds', 'params': {'windowId': wid, 'bounds': {'windowState': 'maximized'}}}))
ws.recv()
ws.close()
" 2>&1

if [ $? -ne 0 ]; then
  MSG="⚠️ **browser-relay**: ウィンドウ最大化失敗"
  curl -s -X POST "$BROWSER_RELAY_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"$MSG\"}" > /dev/null
  exit 1
fi
