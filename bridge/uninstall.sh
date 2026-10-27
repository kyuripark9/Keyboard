#!/bin/bash
# removes clack: quits its menu bar app, stops the background bridge, takes its hooks out of Claude Code's settings and
# Codex's hooks.json and deletes its files
#
#   curl -fsSL https://raw.githubusercontent.com/kyuripark9/Keyboard/main/bridge/uninstall.sh | bash
set -uo pipefail

DIR="$HOME/Library/Application Support/clack"
PORT="${CLACK_PORT:-4545}"

# the menu bar app goes first: the one the Terminal installer made, and the downloaded one or one built by hand
pkill -f "clack menu bar.app/Contents/MacOS/clack" >/dev/null 2>&1 || true
pkill -f "/clack.app/Contents/MacOS/clack" >/dev/null 2>&1 || true
rm -f "$HOME/Library/LaunchAgents/ink.clack.menubar.plist"
rm -rf "$HOME/Applications/clack menu bar.app" "$HOME/Library/WebKit/ink.clack.menubar" "$HOME/Library/Caches/ink.clack.menubar" \
  "$HOME/Library/HTTPStorages/ink.clack.menubar"
defaults delete ink.clack.menubar >/dev/null 2>&1 || true

# clack's hooks come out of Claude Code's settings and Codex's hooks.json the way clack-bridge.py --uninstall-hooks takes
# them out, for the app from the download: its bridge was inside it, so with the app in the Trash there's no
# clack-bridge.py to do it. JavaScript does the editing, as the app did, since macOS always has it
unhook() {
  osascript -l JavaScript - "$1" <<'JS'
function run([path]) {
  ObjC.import('Foundation');
  const text = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  if (text.isNil()) return '';
  let settings;
  try { settings = JSON.parse(text.js); } catch (e) { return `${path} can't be read as JSON, so it was left as it was`; }
  const hooks = settings && typeof settings.hooks === 'object' ? settings.hooks : null;
  if (!hooks) return '';
  const ours = h => { const c = String((h && h.command) || ''); return c.includes('curl') && c.includes('--data-binary @-') &&
    (c.includes('/start') || c.includes('/done') || c.includes('/end')) && c.includes('localhost:'); };
  let n = 0;
  for (const ev of Object.keys(hooks)) {
    const kept = [];
    for (const e of hooks[ev] || []) {
      const inner = (e.hooks || []).filter(h => !ours(h));
      n += (e.hooks || []).length - inner.length;
      if (inner.length) kept.push({ ...e, hooks: inner });
    }
    if (kept.length) hooks[ev] = kept; else delete hooks[ev];
  }
  if (!n) return '';
  if (!Object.keys(hooks).length) delete settings.hooks;
  if (!$(JSON.stringify(settings, null, 2) + '\n').writeToFileAtomicallyEncodingError(path, false, $.NSUTF8StringEncoding, null)) {
    return `${path} couldn't be changed, so clack's hooks are still in it`;
  }
  return `removed ${n} clack hooks from ${path}`;
}
JS
}

if [ ! -f "$DIR/clack-bridge.py" ]; then
  removed=""
  for f in "$HOME/.claude/settings.json" "${CODEX_HOME:-$HOME/.codex}/hooks.json"; do
    said="$(unhook "$f")"
    [ -n "$said" ] && printf '  %s\n' "$said"
    case "$said" in removed*) removed=1 ;; esac
  done
  if [ -n "$removed" ]; then
    printf '\n  clack is removed. If you installed it as an app, drag that out of the Dock or Applications too.\n\n'
  else
    printf '\n  clack is not installed.\n\n'
  fi
  exit 0
fi
PY="$(python3 -c 'import sys; print(sys.executable)' 2>/dev/null || echo python3)"
"$PY" "$DIR/clack-bridge.py" --uninstall-hooks | sed 's/^/  /'
# --no-autostart also deletes the folder it runs from, so it goes last
"$PY" "$DIR/clack-bridge.py" --no-autostart --port "$PORT" | sed 's/^/  /'
rm -f "$HOME/Library/Logs/clack-bridge.log"
printf '\n  clack is removed. If you installed it as an app, drag that out of the Dock or Applications too.\n\n'
