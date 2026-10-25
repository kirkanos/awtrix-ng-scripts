#!/usr/bin/env bash
# Turn an AWTRIX NG panel's display and sound on or off via its REST API.
# Usage: night-mode.sh {off|on|status}
set -euo pipefail

# Values already exported in the environment win over the .env, so remember them
# before sourcing and put them back afterwards.
ENV_HOST="${AWTRIX_HOST:-}"
ENV_USER="${AWTRIX_USER:-}"
ENV_PASS="${AWTRIX_PASS:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${AWTRIX_ENV_FILE:-$SCRIPT_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

[ -n "$ENV_HOST" ] && AWTRIX_HOST="$ENV_HOST"
[ -n "$ENV_USER" ] && AWTRIX_USER="$ENV_USER"
[ -n "$ENV_PASS" ] && AWTRIX_PASS="$ENV_PASS"

: "${AWTRIX_HOST:?Set AWTRIX_HOST in $ENV_FILE (copy .env.example to .env) or in the environment}"

AUTH_ARGS=()
if [ -n "${AWTRIX_USER:-}" ] && [ -n "${AWTRIX_PASS:-}" ]; then
  AUTH_ARGS=(-u "${AWTRIX_USER}:${AWTRIX_PASS}")
fi

BASE_URL="http://${AWTRIX_HOST}/api/v1"

api_patch() {
  local path="$1" body="$2"
  curl -sS -X PATCH "${BASE_URL}${path}" \
    -H "Content-Type: application/json" \
    "${AUTH_ARGS[@]}" \
    -d "$body"
  echo
}

# Lautstaerke heisst "volume" (0-100). Das frueher benutzte "soundEnabled" kennt
# die Firmware seit 1.2 nicht mehr und weist den Request mit 422 ab.
VOL_STATE="${AWTRIX_VOL_STATE:-$SCRIPT_DIR/.volume-$AWTRIX_HOST}"

current_volume() {
  curl -sS "${AUTH_ARGS[@]}" "${BASE_URL}/settings" \
    | sed -E 's/.*"volume":([0-9]+).*/\1/' | head -1
}

usage() {
  echo "Usage: $(basename "$0") {off|on|status}" >&2
  exit 1
}

case "${1:-}" in
  off)
    echo "[$(date '+%F %T')] ${AWTRIX_HOST}: display + sound off"
    # Lautstaerke vorher merken, damit "on" sie wiederherstellen kann
    vol="$(current_volume)"
    case "$vol" in
      ''|*[!0-9]*) ;;
      0) ;;                      # schon stumm - nicht die 0 als "vorher" merken
      *) printf '%s\n' "$vol" > "$VOL_STATE" ;;
    esac
    api_patch "/display" '{"power":false}'
    api_patch "/settings" "{\"volume\":${AWTRIX_NIGHT_VOLUME:-0}}"
    ;;
  on)
    echo "[$(date '+%F %T')] ${AWTRIX_HOST}: display + sound on"
    vol="${AWTRIX_DAY_VOLUME:-}"
    if [ -z "$vol" ] && [ -f "$VOL_STATE" ]; then
      vol="$(cat "$VOL_STATE")"
    fi
    case "$vol" in
      ''|*[!0-9]*) vol=60 ;;     # nichts gemerkt und nichts gesetzt
    esac
    api_patch "/display" '{"power":true}'
    api_patch "/settings" "{\"volume\":${vol}}"
    ;;
  status)
    curl -sS "${AUTH_ARGS[@]}" "${BASE_URL}/display"
    echo
    ;;
  *)
    usage
    ;;
esac
