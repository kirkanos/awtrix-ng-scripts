#!/usr/bin/env bash
# Flashes a status notification (Claude icon, project name, sound) on an
# AWTRIX NG panel.
# Usage: awtrix-notify.sh {done|input}
# Called from Claude Code's Stop / Notification hooks (see ~/.claude/settings.json).
# Claude Code pipes the hook-event JSON (incl. "cwd") on stdin.
#
# Uses LaMetric icon 71832 - must be installed on the device (Icons area of the
# AWTRIX web UI) or the notification just shows without an icon.
set -euo pipefail

INPUT_JSON="$(cat || true)"

AWTRIX_HOST="${AWTRIX_NOTIFY_HOST:-192.168.1.42}"

CWD=""
if command -v jq >/dev/null 2>&1; then
  CWD="$(printf '%s' "$INPUT_JSON" | jq -r '.cwd // empty' 2>/dev/null || true)"
fi
if [ -z "$CWD" ]; then
  CWD="$(printf '%s' "$INPUT_JSON" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*:[[:space:]]*"(.*)"/\1/' || true)"
fi
PROJECT="$(basename "${CWD:-unknown}" 2>/dev/null || true)"
[ -z "$PROJECT" ] && PROJECT="unknown"

case "${1:-}" in
  done)
    LABEL="DONE"
    COLOR="#00FF00"
    SOUND="ok:d=8,o=6,b=180:c,e,g"
    ;;
  input)
    LABEL="HELP"
    COLOR="#FFAA00"
    SOUND="hey:d=8,o=5,b=160:e,c,e,c"
    ;;
  *)
    exit 0
    ;;
esac

TEXT="${LABEL} ${PROJECT}"
# escape backslashes and double quotes for JSON
TEXT="${TEXT//\\/\\\\}"
TEXT="${TEXT//\"/\\\"}"

curl -sS -m 3 -X POST "http://${AWTRIX_HOST}/api/v1/notifications" \
  -H "Content-Type: application/json" \
  -d "{\"icon\":\"71832\",\"text\":\"${TEXT}\",\"textColor\":\"${COLOR}\",\"stack\":false,\"wakeup\":true,\"repeat\":2,\"soundRtttl\":\"${SOUND}\"}" \
  >/dev/null 2>&1 || true

exit 0
