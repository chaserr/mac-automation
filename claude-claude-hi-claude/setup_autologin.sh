#!/bin/zsh
# setup_autologin.sh
# Configures macOS to skip both the login screen (cold boot / pmset poweron)
# and the lock screen (wake from sleep) so the morning LaunchAgent can run
# without any human interaction.
#
# Requirements:
#   - FileVault must be OFF  (fdesetup status)
#   - Run as a normal user; sudo is requested only where needed
#
# Usage:
#   chmod +x setup_autologin.sh
#   ./setup_autologin.sh

set -euo pipefail

USERNAME=$(whoami)
OS_VERSION=$(sw_vers -productVersion)

echo "=== macOS Auto-Login Setup ==="
echo "User   : $USERNAME"
echo "macOS  : $OS_VERSION"
echo

# ── Guard: FileVault must be off ──────────────────────────────────────────────
fv_status=$(fdesetup status 2>/dev/null || echo "unknown")
if [[ "$fv_status" != *"Off"* && "$fv_status" != *"off"* ]]; then
  echo "ERROR: FileVault is ON (or status unknown)."
  echo "       Auto-login cannot be enabled while FileVault is active."
  echo "       Disable FileVault first: System Settings → Privacy & Security → FileVault"
  exit 1
fi
echo "✓ FileVault is off"

# ── Part 1: Auto-login (skips login screen after cold boot / pmset poweron) ──
echo
echo "── Part 1: Auto-Login ──────────────────────────────────────────────────────"
echo "This writes /etc/kcpassword so macOS logs in as '$USERNAME' automatically."
echo "Your login password will be XOR-obfuscated (standard macOS mechanism)."
echo

# Read password without echoing it
print -n "Enter your macOS login password: "
read -rs LOGIN_PASSWORD
echo

# Write the autoLoginUser preference
sudo defaults write /Library/Preferences/com.apple.loginwindow \
  autoLoginUser -string "$USERNAME"

# Write /etc/kcpassword  (XOR with Apple's fixed 11-byte key)
sudo python3 - "$LOGIN_PASSWORD" << 'PYEOF'
import sys, os, stat

password = sys.argv[1]
key = [0x7D, 0x89, 0x52, 0x23, 0xD2, 0xBC, 0xDD, 0xEA, 0xA3, 0xB9, 0x1F]
pwd_bytes = list(password.encode("utf-8")) + [0]
# Pad to a multiple of 11
while len(pwd_bytes) % 11 != 0:
    pwd_bytes.append(0)
xored = bytes(b ^ key[i % 11] for i, b in enumerate(pwd_bytes))
with open("/etc/kcpassword", "wb") as f:
    f.write(xored)
os.chmod("/etc/kcpassword", stat.S_IRUSR | stat.S_IWUSR)   # 0o600
print("✓ /etc/kcpassword written (root-only, mode 600)")
PYEOF

# Clear the variable immediately
unset LOGIN_PASSWORD

echo "✓ Auto-login enabled for user: $USERNAME"

# ── Part 2: Disable lock screen after sleep / screen saver ───────────────────
echo
echo "── Part 2: Disable Lock Screen After Sleep / Screensaver ───────────────────"
echo "Prevents the lock screen from appearing when:"
echo "  • Mac wakes from display/system sleep"
echo "  • Screen saver activates"
echo "  • Display turns off due to inactivity"
echo
echo "NOTE: This does NOT bypass a manual lock (⌃⌘Q or Apple menu → Lock Screen)."
echo "      macOS uses Secure Event Input on the lock screen which blocks all"
echo "      programmatic keyboard input. Avoid manually locking the night before."
echo

# 1. No password after sleep/screensaver (global and per-host on macOS 13+)
defaults write             com.apple.screensaver askForPassword      -int 0
defaults write             com.apple.screensaver askForPasswordDelay -int 0
defaults -currentHost write com.apple.screensaver askForPassword      -int 0
defaults -currentHost write com.apple.screensaver askForPasswordDelay -int 0

# 2. Disable the screen saver itself (idleTime=0 → never triggers)
defaults -currentHost write com.apple.screensaver idleTime -int 0

# 3. Belt-and-suspenders: loginwindow domain on some macOS versions
defaults write com.apple.loginwindow DisableScreenLock -bool true 2>/dev/null || true

# 4. Keep display awake long enough to span the morning trigger window.
#    Default displaysleep is often 10 min; bump to 180 min so a Mac left on
#    overnight is still showing the desktop (not asleep) at 06:50.
sudo pmset -a displaysleep 180 2>/dev/null || \
  echo "  (skipped pmset displaysleep — run 'sudo pmset -a displaysleep 180' manually)"

echo "✓ Lock screen after sleep/screensaver disabled"
echo "✓ Screen saver disabled (idleTime=0)"
echo "✓ Display sleep extended to 180 min"

# ── Summary ───────────────────────────────────────────────────────────────────
echo
echo "=== Setup Complete ==="
echo
echo "What was configured:"
echo "  1. Auto-login: macOS will log in as '$USERNAME' automatically on boot/poweron"
echo "  2. Lock screen: No password after sleep/screensaver; screensaver disabled"
echo "  3. Display sleep extended to 180 min (covers overnight idle)"
echo
echo "What is NOT covered (by design):"
echo "  • Manual lock (⌃⌘Q or Apple menu → Lock Screen) — macOS Secure Event Input"
echo "    blocks programmatic unlock. Don't manually lock before 06:50."
echo
echo "Next steps:"
echo "  • Reboot once to verify auto-login works before relying on the morning schedule."
echo "  • If a lock screen still appears after sleep, also check:"
echo "    System Settings → Lock Screen"
echo "    → 'Require password after screen saver begins or display is turned off' → Never"
echo "    → 'Start Screen Saver when inactive' → Never"
echo
echo "To verify settings:"
echo "  sudo defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser"
echo "  defaults -currentHost read com.apple.screensaver askForPassword"
echo "  pmset -g | grep displaysleep"
