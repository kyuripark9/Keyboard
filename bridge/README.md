# clack for your Mac

clack wakes up when you hand a task to your coding agent, gives your hands something to do while it works, and lets go
of you the moment it's done. This folder is what runs it on your own computer.

## Install

The easy way is the app: download [clack.dmg](https://kyuripark9.github.io/Keyboard/clack.dmg), open it and drag clack
into Applications. It's built for Apple silicon and Intel Macs on macOS 12 or later, with this bridge inside
([menubar/clack-bridge.swift](../menubar/clack-bridge.swift), the same as `clack-bridge.py`), so it needs nothing else.

1. The first time you open it, macOS stops it, as it isn't from the App Store: click Done, then in System Settings ›
   Privacy & Security, scroll down and click Open Anyway. (Opened straight from the download, clack offers to move
   itself into Applications first.)
2. It opens under its ring in the menu bar and asks once whether to connect to Claude Code and Codex, whichever are on
   your Mac (five small hooks each, in `~/.claude/settings.json` and `~/.codex/hooks.json`, backed up first).
   Right-click the ring and choose Connect to Claude Code or Connect to Codex to change that any time.
3. From then on it opens at login, and its bridge runs while the ring is there.

Download it again to update. To remove it, right-click the ring and choose Remove clack: it takes its hooks out of
Claude Code's and Codex's settings, stops opening at login, forgets its settings and moves itself to the Trash.

### From Terminal

Or open Terminal and paste:

```sh
curl -fsSL https://raw.githubusercontent.com/kyuripark9/Keyboard/main/bridge/install.sh | bash
```

It takes a few seconds and:

1. puts clack in `~/Library/Application Support/clack`
2. runs it in the background from now on, also after a restart
3. puts clack's ring in your menu bar (`~/Applications/clack menu bar.app`, built on your Mac)
4. asks whether to connect it to Claude Code (five small hooks in `~/.claude/settings.json`, backed up first), and to
   Codex (five in `~/.codex/hooks.json`)
5. opens clack under the ring

Run the same line again any time to update to the latest clack.

It needs macOS and Python 3, which comes with Apple's Command Line Tools (so does the Swift compiler that builds the menu
bar app). If they are missing, the installer opens Apple's window to install them; run the line again once that's done.

## Keep it beside your agent

- **In the menu bar**: clack's ring sits at the top right of the screen whatever app you're in (Claude, ChatGPT, a
  terminal). Click it and clack opens under it, and stays there over your other apps while you click and type in them
  until you click the ring again or press Esc in it. Drag clack's left, right or bottom edge to make it bigger or
  smaller, or click the button at its top right to expand it to Full Height and shrink it back. The ring shows your
  agent without opening anything: it breathes while the agent works, holds still with its dot filled in when it's
  done, and dims when the bridge is offline. Right-click it to pick a size (Small, Medium, Large, or Full Height down
  to the Dock), open clack in your browser, reload it, connect it to Claude Code or Codex or take it out again, choose whether
  it opens at login (it does unless you turn that off) or quit it. Opening clack again from Applications or Spotlight
  opens it under the ring too; when the menu bar is so full that macOS hides the ring behind the camera, clack says so
  and offers to open in your browser instead.
- **As its own app**: open http://localhost:4545 in Chrome or Edge and click the install icon in the address bar, or in
  Safari choose *File > Add to Dock*. clack then opens from the Dock in its own window, which you can keep next to the
  Claude or ChatGPT app, a terminal or your editor.
- **In the Claude desktop app**: open the side panel's browser (Cmd+Shift+B) and go to `localhost:4545`.

## Codex and the ChatGPT app

Codex, OpenAI's agent, has hooks too, and on the Mac the ChatGPT app runs its conversations in Codex, so clack follows
both the Codex CLI and the ChatGPT app once it's connected. Codex runs no hook until you've looked at it, so after
connecting, trust clack's five once: in the ChatGPT app, open Settings › Hooks, where they show as new hooks; in the
Codex CLI, type `/hooks`. ChatGPT in a browser runs on OpenAI's servers rather than your Mac, so it has no hooks for
clack to hear; there, clack is something to play with while you wait, and the demo agent stands in.

## What it knows, and what it keeps

Claude Code's hooks tell the bridge that you sent a prompt, that Claude stopped (and whether it left work of its own
running in the background, such as a shell command or a subagent) or stopped on an error, that it needs your permission
for something, and that a session closed. clack uses that to know when you're waiting and when to let go. With several
sessions working at once, the first to finish lets go of you; once you've gone back, clack holds you again while the
others work, and the next to finish lets go again. The time it shows is how long since you last sent a prompt to a
session that's still working. A shell Claude leaves running counts as its own work for ten minutes; one that's still
going after that is taken for a server (a dev server it started for you, say), and that session lets go. The bridge looks at a prompt only to tell yours apart from Claude
waking itself up, and at the last lines of a working session's transcript only to see whether you stopped it with Esc,
which no hook reports. For the Claude app's Code tab, where Claude Code passes a permission prompt on only 6 seconds
late, it also reads the app's log (`~/Library/Logs/Claude/main.log`) for the line the app writes the moment it shows
you one.

Codex's hooks tell it the same: that you sent a prompt, that a turn ended, that Codex asks your permission for
something, that you stopped it with Esc and that a conversation closed. When a turn's approvals go to Codex's
auto-reviewer, which answers them by itself, a permission request isn't a call back, so clack keeps holding you; the
bridge reads who reviews from the line each turn starts with in its transcript. A Codex turn that ends on an error
calls no hook, so the bridge also reads the end of a working session's transcript for how its turn ended. It stores
none of this, and never sees your code. Nothing leaves your Mac: the bridge only listens on `localhost`. How quickly you went back is kept in your browser, and only shown as your last and typical return.

## Remove

The app: right-click its ring and choose Remove clack. Installed from Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/kyuripark9/Keyboard/main/bridge/uninstall.sh | bash
```

This quits the menu bar app, stops the bridge, takes the hooks back out of Claude Code's and Codex's settings and
deletes clack's files.

## Without the installer

On any system with Python 3.8+ or Node 18+, clone this repo and run the bridge from it:

```sh
git clone https://github.com/kyuripark9/Keyboard clack && cd clack
python3 bridge/clack-bridge.py --install         # connect Claude Code
python3 bridge/clack-bridge.py --install-codex   # connect Codex and the ChatGPT app (then trust its hooks there)
python3 bridge/clack-bridge.py                   # run it (or: node bridge/clack-bridge.js), then open http://localhost:4545
```

On a Mac, build the menu bar app from the clone too, which runs the bridge itself when no other one answers on its
port:

```sh
bash menubar/build.sh && open menubar/build/clack.app
```

It listens on port 4545; for another, `defaults write ink.clack.menubar port -int 4600` (or start it with `CLACK_PORT`).
