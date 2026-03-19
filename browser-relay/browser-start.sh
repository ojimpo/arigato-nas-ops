#!/bin/bash
# Start OpenClaw browser with retry. Notify Discord on failure.
# Required env: OPENCLAW_GATEWAY_TOKEN, BROWSER_RELAY_WEBHOOK, OPENCLAW_CONTROL_PORT

CONTROL_PORT="${OPENCLAW_CONTROL_PORT:-18791}"

for i in 1 2 3 4 5 6; do
  sleep 5
  if curl -sf -X POST "http://127.0.0.1:${CONTROL_PORT}/start" \
    -H "Authorization: Bearer $OPENCLAW_GATEWAY_TOKEN" > /dev/null; then
    exit 0
  fi
done

MSG="❌ **browser-relay**: Chrome起動失敗（30秒タイムアウト）"
curl -s -X POST "$BROWSER_RELAY_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"$MSG\"}" > /dev/null
exit 1
