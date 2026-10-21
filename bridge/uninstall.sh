#!/bin/bash
# removes clack: stops the background bridge, takes its hooks out of Claude Code's settings and deletes its files
#
#   curl -fsSL https://raw.githubusercontent.com/kyuripark9/Keyboard/claude/keyboard-toy-6bkf2n/bridge/uninstall.sh | bash
set -uo pipefail

DIR="$HOME/Library/Application Support/clack"
PORT="${CLACK_PORT:-4545}"

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
