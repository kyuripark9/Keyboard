# clack for your Mac

clack wakes up when you hand a task to your coding agent, gives your hands something to do while it works, and lets go
of you the moment it's done. This folder is what runs it on your own computer.

## Install

Open Terminal and paste:

```sh
curl -fsSL https://raw.githubusercontent.com/kyuripark9/Keyboard/main/bridge/install.sh | bash
```

It takes a few seconds and:

1. puts clack in `~/Library/Application Support/clack`
2. runs it in the background from now on, also after a restart
3. puts clack's ring in your menu bar (`~/Applications/clack menu bar.app`, built on your Mac)
4. asks whether to connect it to Claude Code (five small hooks in `~/.claude/settings.json`, backed up first)
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
  to the Dock), open clack in your browser, reload it, choose whether it opens at login (it does unless you turn that
  off) or quit it.
- **As its own app**: open http://localhost:4545 in Chrome or Edge and click the install icon in the address bar, or in
  Safari choose *File > Add to Dock*. clack then opens from the Dock in its own window, which you can keep next to the
  Claude or ChatGPT app, a terminal or your editor.
- **In the Claude desktop app**: open the side panel's browser (Cmd+Shift+B) and go to `localhost:4545`.

## What it knows, and what it keeps

Claude Code's hooks tell the bridge that you sent a prompt, that Claude stopped (and whether it left work of its own
running in the background, such as a shell command or a subagent) or stopped on an error, that it needs your permission
for something, and that a session closed. clack uses that to know when you're waiting and when to let go. With several
sessions working at once, the first to finish lets go of you; once you've gone back, clack holds you again while the
others work, and the next to finish lets go again. The bridge looks at a prompt only to tell yours apart from Claude
waking itself up, and at the last lines of a working session's transcript only to see whether you stopped it with Esc,
which no hook reports. For the Claude app's Code tab, where Claude Code passes a permission prompt on only 6 seconds
late, it also reads the app's log (`~/Library/Logs/Claude/main.log`) for the line the app writes the moment it shows
you one. It stores none of this, and never sees your code. Nothing leaves your Mac: the bridge only listens on `localhost`. How quickly you went back is kept in your browser, and only shown as your last and typical return.

## Remove

```sh
curl -fsSL https://raw.githubusercontent.com/kyuripark9/Keyboard/main/bridge/uninstall.sh | bash
```

This quits the menu bar app, stops the bridge, takes the hooks back out of Claude Code's settings and deletes clack's
files.

## Without the installer

On any system with Python 3.8+ or Node 18+, clone this repo and run the bridge from it:

```sh
git clone https://github.com/kyuripark9/Keyboard clack && cd clack
python3 bridge/clack-bridge.py --install   # connect Claude Code
python3 bridge/clack-bridge.py             # run it (or: node bridge/clack-bridge.js), then open http://localhost:4545
```

On a Mac, build the menu bar app from the clone too:

```sh
bash menubar/build.sh && open menubar/build/clack.app
```

It listens on port 4545; for another, `defaults write ink.clack.menubar port -int 4600` (or start it with `CLACK_PORT`).
