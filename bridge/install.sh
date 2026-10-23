#!/bin/bash
# clack installer for macOS
#
#   curl -fsSL https://raw.githubusercontent.com/kyuripark9/Keyboard/main/bridge/install.sh | bash
#
# Puts clack in ~/Library/Application Support/clack, runs it in the background from login on, puts its ring in the menu
# bar, offers to connect it to Claude Code and Codex, and opens it. Running it again updates clack to the latest version. Nothing
# leaves your Mac: clack and its bridge only listen on localhost.
set -euo pipefail

SOURCE="${CLACK_SOURCE:-https://raw.githubusercontent.com/kyuripark9/Keyboard/main}"
PORT="${CLACK_PORT:-4545}"
DIR="$HOME/Library/Application Support/clack"
FILES="bridge/clack-bridge.py bridge/icon-192.png bridge/icon-512.png bridge/apple-touch-icon.png bridge/favicon-32.png index.html menubar/clack-menubar.swift menubar/clack-bridge.swift menubar/build.sh"
# not ~/Applications/clack.app, which is where Safari's File > Add to Dock keeps clack as a web app
MENUBAR="$HOME/Applications/clack menu bar.app"

say() { printf '  %s\n' "$*"; }
fail() { printf '\n  clack: %s\n\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || fail "this installer is for macOS. Elsewhere, download bridge/clack-bridge.py and index.html and run: python3 clack-bridge.py"

# macOS ships python3 with the Command Line Tools; without them, /usr/bin/python3 only offers to install them
if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 8))' >/dev/null 2>&1; then
  xcode-select --install >/dev/null 2>&1 || true
  fail "clack needs Python 3, which comes with Apple's Command Line Tools. Install them from the window that just opened, then run this again."
fi
PY="$(python3 -c 'import sys; print(sys.executable)')"

printf '\n  clack\n\n'

# an earlier install keeps running until it is replaced
if [ -f "$DIR/clack-bridge.py" ]; then
  say "Updating your clack…"
  "$PY" "$DIR/clack-bridge.py" --no-autostart --port "$PORT" >/dev/null 2>&1 || true
else
  say "Installing clack…"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for f in $FILES; do
  curl -fsSL "$SOURCE/$f" -o "$TMP/$(basename "$f")" || fail "could not download $f. Check your connection and run this again."
done
mkdir -p "$DIR"
mv "$TMP"/* "$DIR"/

"$PY" "$DIR/clack-bridge.py" --autostart --port "$PORT" | sed 's/^/  /' || fail "the background bridge did not start. See ~/Library/Logs/clack-bridge.log"

# the menu bar app: clack's ring at the top right of the screen, which opens clack from any app; it is built here with
# the Swift compiler that comes with the Command Line Tools, and an older one keeps running until it is replaced
say "Building the menu bar app…"
if bash "$DIR/build.sh" "$MENUBAR" >/dev/null 2>"$TMP/menubar.log"; then
  defaults write ink.clack.menubar port -int "$PORT"
  pkill -f "clack menu bar.app/Contents/MacOS/clack" >/dev/null 2>&1 || true
else
  say "The menu bar app could not be built, so clack stays in your browser:"
  tail -n 3 "$TMP/menubar.log" | sed 's/^/    /'
  MENUBAR=""
fi

# Claude Code and Codex: only with the user's yes, read from the keyboard even though this script came in through a
# pipe; with nobody at the keyboard to say yes, their settings are left alone
yes_to() {
  local answer="n"
  if { exec 3</dev/tty; } 2>/dev/null; then
    printf '\n  %s\n  %s [Y/n] ' "$1" "$2"
    read -r answer <&3 || answer="n"
    exec 3<&-
  fi
  case "$answer" in n|N|no|No) return 1 ;; esac
}
if [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; then
  if yes_to "Connect clack to Claude Code, so it knows when your agent starts and finishes?" \
    "This adds five small hooks to ~/.claude/settings.json and backs it up first."; then
    "$PY" "$DIR/clack-bridge.py" --install --port "$PORT" | sed 's/^/  /'
    say "Claude Code sessions you start from now on will tell clack when they finish."
  else
    say "Skipped. Connect it later with: python3 \"$DIR/clack-bridge.py\" --install"
  fi
fi
# the ChatGPT app on the Mac runs its conversations in Codex, and keeps Codex's settings in ~/.codex too
if [ -d "${CODEX_HOME:-$HOME/.codex}" ] || command -v codex >/dev/null 2>&1; then
  if yes_to "Connect clack to Codex and the ChatGPT app, so it knows when your agent starts and finishes?" \
    "This adds five small hooks to ~/.codex/hooks.json and backs it up first."; then
    "$PY" "$DIR/clack-bridge.py" --install-codex --port "$PORT" | sed 's/^/  /'
  else
    say "Skipped. Connect it later with: python3 \"$DIR/clack-bridge.py\" --install-codex"
  fi
fi

if [ -n "$MENUBAR" ]; then
  printf '\n  clack is in your menu bar: click its ring at the top right of the screen, from any app.\n'
  say "The ring breathes while your agent works and fills in when it's done. Right-click it for more."
else
  printf '\n  clack is ready at http://localhost:%s\n' "$PORT"
  say "Keep it as an app: in Chrome, click the install icon in the address bar; in Safari, choose File > Add to Dock."
  say "In the Claude app, open the side panel's browser (Cmd+Shift+B) and go to localhost:$PORT."
fi
say "Remove it any time: curl -fsSL $SOURCE/bridge/uninstall.sh | bash"
printf '\n'
if [ -n "$MENUBAR" ]; then
  open "$MENUBAR" --args --show >/dev/null 2>&1 || true
else
  open "http://localhost:$PORT" >/dev/null 2>&1 || true
fi
