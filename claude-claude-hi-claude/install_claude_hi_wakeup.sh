#!/bin/zsh
set -euo pipefail

LABEL="com.local.claude-hi"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
RUN_SCRIPT="${SCRIPT_DIR}/run_claude_hi.sh"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="${HOME}/Library/Logs/claude-hi-wakeup"
OUT_LOG="${LOG_DIR}/out.log"
ERR_LOG="${LOG_DIR}/err.log"

WAKE_TIME="${WAKE_TIME:-06:00:00}"
LAUNCH_HOUR="${LAUNCH_HOUR:-6}"
LAUNCH_MINUTE="${LAUNCH_MINUTE:-0}"
DAYS="${DAYS:-MTWRFSU}"

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  echo "${value}"
}

if [[ ! -f "${RUN_SCRIPT}" ]]; then
  echo "Missing runner script: ${RUN_SCRIPT}" >&2
  exit 1
fi

chmod +x "${RUN_SCRIPT}"
mkdir -p "${HOME}/Library/LaunchAgents" "${LOG_DIR}"

RUN_SCRIPT_XML="$(xml_escape "${RUN_SCRIPT}")"
OUT_LOG_XML="$(xml_escape "${OUT_LOG}")"
ERR_LOG_XML="$(xml_escape "${ERR_LOG}")"
SCRIPT_DIR_XML="$(xml_escape "${SCRIPT_DIR}")"

launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
launchctl bootout "gui/$(id -u)" "${PLIST}" >/dev/null 2>&1 || true

cat > "${PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>

  <key>ProgramArguments</key>
  <array>
    <string>${RUN_SCRIPT_XML}</string>
  </array>

  <key>WorkingDirectory</key>
  <string>${SCRIPT_DIR_XML}</string>

  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>${LAUNCH_HOUR}</integer>
    <key>Minute</key>
    <integer>${LAUNCH_MINUTE}</integer>
  </dict>

  <key>RunAtLoad</key>
  <true/>

  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>

  <key>StandardOutPath</key>
  <string>${OUT_LOG_XML}</string>

  <key>StandardErrorPath</key>
  <string>${ERR_LOG_XML}</string>
</dict>
</plist>
PLIST

plutil -lint "${PLIST}" >/dev/null
launchctl bootstrap "gui/$(id -u)" "${PLIST}"
launchctl enable "gui/$(id -u)/${LABEL}"

if [[ "${SKIP_PMSET:-0}" != "1" ]]; then
  echo "Current macOS power schedule:"
  SCHED_OUTPUT="$(pmset -g sched 2>/dev/null || true)"
  echo "${SCHED_OUTPUT}"
  echo

  # Extract the hour from WAKE_TIME (e.g. "06:50:00" → "6")
  WAKE_HOUR="${WAKE_TIME%%:*}"
  WAKE_HOUR="${WAKE_HOUR#0}"   # strip leading zero for comparison
  WAKE_MIN="${WAKE_TIME#*:}"
  WAKE_MIN="${WAKE_MIN%%:*}"
  WAKE_MIN="${WAKE_MIN#0}"

  # Check if a matching repeating wakepoweron already exists (e.g. "6:50AM")
  if echo "${SCHED_OUTPUT}" | grep -qi "wakepoweron.*${WAKE_HOUR}:${WAKE_MIN}"; then
    echo "✓ Wake/power-on schedule already set to ${WAKE_TIME} — skipping pmset."
  else
    echo "Configuring wake/power-on schedule: ${DAYS} ${WAKE_TIME}"
    echo "Note: 'pmset repeat' may replace an existing repeating wake/power schedule."
    if sudo pmset repeat wakeorpoweron "${DAYS}" "${WAKE_TIME}"; then
      echo "✓ Wake/power-on schedule updated."
    else
      echo
      echo "⚠ Could not run sudo automatically. Run this once manually in a terminal:"
      echo
      echo "  sudo pmset repeat wakeorpoweron ${DAYS} ${WAKE_TIME}"
      echo
    fi
  fi
else
  echo "Skipped pmset because SKIP_PMSET=1."
fi

echo
echo "Installed LaunchAgent: ${PLIST}"
echo "Logs:"
echo "  ${OUT_LOG}"
echo "  ${ERR_LOG}"
echo
echo "Manual test:"
echo "  ${RUN_SCRIPT} --force"
