#!/bin/zsh
set -euo pipefail

LABEL="com.local.claude-hi"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"

launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
launchctl bootout "gui/$(id -u)" "${PLIST}" >/dev/null 2>&1 || true

rm -f "${PLIST}"

if [[ "${1:-}" == "--cancel-wake-schedule" ]]; then
  echo "Cancelling all repeating macOS power events."
  sudo pmset repeat cancel
else
  echo "LaunchAgent removed."
  echo "Wake/power schedule was not changed."
  echo "To cancel repeating macOS power events too, run:"
  echo "  $0 --cancel-wake-schedule"
fi
