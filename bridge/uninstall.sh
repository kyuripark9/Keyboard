#!/bin/bash
# removes clack: quits its menu bar app, stops the background bridge, takes its hooks out of Claude Code's settings and
# deletes its files
#
#   curl -fsSL https://raw.githubusercontent.com/kyuripark9/Keyboard/claude/keyboard-toy-6bkf2n/bridge/uninstall.sh | bash
set -uo pipefail

DIR="$HOME/Library/Application Support/clack"
PORT="${CLACK_PORT:-4545}"

# the menu bar app goes first, and also when it was built by hand without the rest
pkill -f "clack menu bar.app/Contents/MacOS/clack" >/dev/null 2>&1 || true
pkill -f "menubar/build/clack.app/Contents/MacOS/clack" >/dev/null 2>&1 || true
rm -f "$HOME/Library/LaunchAgents/ink.clack.menubar.plist"
rm -rf "$HOME/Applications/clack menu bar.app" "$HOME/Library/WebKit/ink.clack.menubar" "$HOME/Library/Caches/ink.clack.menubar" \
  "$HOME/Library/HTTPStorages/ink.clack.menubar"
defaults delete ink.clack.menubar >/dev/null 2>&1 || true

if [ ! -f "$DIR/clack-bridge.py" ]; then
  printf '\n  clack is not installed.\n\n'
  exit 0
fi
PY="$(python3 -c 'import sys; print(sys.executable)' 2>/dev/null || echo python3)"
"$PY" "$DIR/clack-bridge.py" --uninstall-hooks | sed 's/^/  /'
# --no-autostart also deletes the folder it runs from, so it goes last
"$PY" "$DIR/clack-bridge.py" --no-autostart --port "$PORT" | sed 's/^/  /'
rm -f "$HOME/Library/Logs/clack-bridge.log"
printf '\n  clack is removed. If you installed it as an app, drag that out of the Dock or Applications too.\n\n'
