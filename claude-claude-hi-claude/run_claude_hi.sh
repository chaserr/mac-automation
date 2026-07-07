#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
APPLE_SCRIPT="${SCRIPT_DIR}/claude_hi.applescript"
STAMP_FILE="${HOME}/.cache/claude-hi/last-run"

# Time-window guard. RunAtLoad=true means the LaunchAgent also fires shortly
# after boot/login — combined with StartCalendarInterval at 06:50, the agent
# can fire multiple times per day. This window keeps runs near the intended
# morning slot; the stamp file below makes it idempotent within that window.
WINDOW_START="${WINDOW_START:-05:55}"
WINDOW_END="${WINDOW_END:-07:00}"

time_to_minutes() {
  local value="$1"
  local hour="${value%%:*}"
  local minute="${value##*:}"
  echo $((10#${hour} * 60 + 10#${minute}))
}

force_mode=0
if [[ "${1:-}" == "--force" ]]; then
  force_mode=1
fi

# 1. Time-window guard (bypassed with --force).
if (( ! force_mode )); then
  now_minutes=$((10#$(date +%H) * 60 + 10#$(date +%M)))
  start_minutes="$(time_to_minutes "${WINDOW_START}")"
  end_minutes="$(time_to_minutes "${WINDOW_END}")"

  if (( now_minutes < start_minutes || now_minutes > end_minutes )); then
    echo "Skip: current time is outside ${WINDOW_START}-${WINDOW_END}."
    exit 0
  fi
fi

# 2. Once-per-day guard. If StartCalendarInterval fires after RunAtLoad
# already triggered (e.g. machine was already on at 06:50, or user logged in
# manually inside the window and then the calendar fired), the stamp file
# prevents a second iTerm window. Bypassed with --force.
today="$(date +%Y-%m-%d)"
if (( ! force_mode )) && [[ -f "${STAMP_FILE}" ]]; then
  last_run="$(cat "${STAMP_FILE}" 2>/dev/null || echo "")"
  if [[ "${last_run}" == "${today}" ]]; then
    echo "Skip: claude-hi already ran today (${today}) — see ${STAMP_FILE}."
    exit 0
  fi
fi

if [[ ! -f "${APPLE_SCRIPT}" ]]; then
  echo "Missing AppleScript: ${APPLE_SCRIPT}" >&2
  exit 1
fi

# Always open a fresh iTerm window and run proxy_on + claude + "hi", even if
# a claude process is already alive elsewhere. (No process-level guard — the
# once-per-day stamp above is the only dedup.)
/usr/bin/osascript "${APPLE_SCRIPT}"

# 3. Record successful run for the once-per-day guard.
mkdir -p "$(dirname "${STAMP_FILE}")"
echo "${today}" > "${STAMP_FILE}"
