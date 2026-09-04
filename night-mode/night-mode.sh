#!/usr/bin/env bash
# Turn an AWTRIX NG panel's display and sound on or off via its REST API.
# Usage: night-mode.sh {off|on|status}
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${AWTRIX_ENV_FILE:-$SCRIPT_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

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

usage() {
  echo "Usage: $(basename "$0") {off|on|status}" >&2
  exit 1
}

case "${1:-}" in
  off)
    echo "[$(date '+%F %T')] ${AWTRIX_HOST}: display + sound off"
    api_patch "/display" '{"power":false}'
    api_patch "/settings" '{"soundEnabled":false}'
    ;;
  on)
    echo "[$(date '+%F %T')] ${AWTRIX_HOST}: display + sound on"
    api_patch "/display" '{"power":true}'
    api_patch "/settings" '{"soundEnabled":true}'
    ;;
  status)
    curl -sS "${AUTH_ARGS[@]}" "${BASE_URL}/display"
    echo
    ;;
  *)
    usage
    ;;
esac
