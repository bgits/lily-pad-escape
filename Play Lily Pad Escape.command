#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if curl -fsS --max-time 2 http://127.0.0.1:8765/ | grep -q '<title>Lily Pad Escape</title>'; then
  open http://127.0.0.1:8765/
  exit 0
fi
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web &
LILY_SERVER_PID=$!
trap 'kill "$LILY_SERVER_PID" 2>/dev/null || true' EXIT INT TERM
sleep 1
open http://127.0.0.1:8765/
echo 'Lily Pad Escape is running. Keep this window open while you play. Press Control-C to stop.'
wait "$LILY_SERVER_PID"
