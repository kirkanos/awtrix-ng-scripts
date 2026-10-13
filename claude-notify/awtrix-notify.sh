#!/usr/bin/env bash
# Flashes a status notification (Claude icon, project name, sound) on an
# AWTRIX NG panel.
# Usage: awtrix-notify.sh {done|input}
# Called from Claude Code's Stop / Notification hooks (see ~/.claude/settings.json).
# Claude Code pipes the hook-event JSON (incl. "cwd") on stdin.
#
# The panel's address comes from AWTRIX_NOTIFY_HOST, or from a .env next to the
# script (copy .env.example). Without it the script exits quietly - a missing
# config must never block Claude Code.
#
# Optional: with AWTRIX_DECK_PORT set, the same state is also posted to the
# "AWTRIX Remote" Stream Deck plugin listening on 127.0.0.1:<port>. Without
# the variable nothing is sent there, and a plugin that is not running is
# ignored, so the panel notification works with and without a Stream Deck.
#
# Uses LaMetric icon 71832 - must be installed on the device (Icons area of the
# AWTRIX web UI) or the notification just shows without an icon.
#
# The sound goes in as {"sound":{"rtttl":...}}. Firmware 1.2 dropped the old
# flat "soundRtttl" field and rejects the WHOLE request with 422 when it is
# used, so the notification silently stopped appearing.
set -euo pipefail

INPUT_JSON="$(cat || true)"

# An exported AWTRIX_NOTIFY_HOST wins over the .env, so remember it before sourcing.
AWTRIX_HOST="${AWTRIX_NOTIFY_HOST:-}"
DECK_PORT="${AWTRIX_DECK_PORT:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${AWTRIX_NOTIFY_ENV_FILE:-$SCRIPT_DIR/.env}"
if [ -z "$AWTRIX_HOST" ] && [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  AWTRIX_HOST="${AWTRIX_NOTIFY_HOST:-}"
fi
if [ -z "$DECK_PORT" ] && [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  DECK_PORT="${AWTRIX_DECK_PORT:-}"
fi

[ -z "$AWTRIX_HOST" ] && [ -z "$DECK_PORT" ] && exit 0

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

if [ -n "$AWTRIX_HOST" ]; then
  curl -sS -m 3 -X POST "http://${AWTRIX_HOST}/api/v1/notifications" \
    -H "Content-Type: application/json" \
    -d "{\"icon\":\"71832\",\"text\":\"${TEXT}\",\"textColor\":\"${COLOR}\",\"stack\":false,\"wakeup\":true,\"repeat\":2,\"sound\":{\"rtttl\":\"${SOUND}\"}}" \
    >/dev/null 2>&1 || true
fi

# Stream Deck plugin (AWTRIX Remote, Claude Status key): same state, local only.
if [ -n "$DECK_PORT" ]; then
  PROJECT_JSON="${PROJECT//\\/\\\\}"
  PROJECT_JSON="${PROJECT_JSON//\"/\\\"}"
  curl -sS -m 1 -X POST "http://127.0.0.1:${DECK_PORT}/" \
    -H "Content-Type: application/json" \
    -d "{\"state\":\"${1}\",\"project\":\"${PROJECT_JSON}\"}" \
    >/dev/null 2>&1 || true
fi

exit 0
