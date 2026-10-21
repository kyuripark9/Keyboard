# clack for your Mac

clack wakes up when you hand a task to your coding agent, gives your hands something to do while it works, and lets go
of you the moment it's done. This folder is what runs it on your own computer.

## Install

Open Terminal and paste:

```sh
curl -fsSL https://raw.githubusercontent.com/kyuripark9/Keyboard/claude/keyboard-toy-6bkf2n/bridge/install.sh | bash
```

It takes a few seconds and:

1. puts clack in `~/Library/Application Support/clack`
2. runs it in the background from now on, also after a restart
3. asks whether to connect it to Claude Code (three small hooks in `~/.claude/settings.json`, backed up first)
4. opens http://localhost:4545

Run the same line again any time to update to the latest clack.

It needs macOS and Python 3, which comes with Apple's Command Line Tools. If they are missing, the installer opens
Apple's window to install them; run the line again once that's done.

## Keep it beside your agent

- **As its own app**: open http://localhost:4545 in Chrome or Edge and click the install icon in the address bar, or in
  Safari choose *File > Add to Dock*. clack then opens from the Dock in its own window, which you can keep next to the
  Claude or ChatGPT app, a terminal or your editor.
- **In the Claude desktop app**: open the side panel's browser (Cmd+Shift+B) and go to `localhost:4545`.

## What it knows, and what it keeps

Claude Code's hooks tell the bridge three things: that you sent a prompt, that Claude stopped (and whether it left
background tasks running), and that it needs your permission for something. clack uses that to know when you're waiting
and when to let go. The bridge looks at a prompt only to tell yours apart from Claude waking itself up, never stores
it, and never sees your code. Nothing leaves your Mac: the bridge only listens on `localhost`. How quickly you went back is kept in your browser, and only shown as your last and typical return.

## Remove

```sh
curl -fsSL https://raw.githubusercontent.com/kyuripark9/Keyboard/claude/keyboard-toy-6bkf2n/bridge/uninstall.sh | bash
```

This stops the bridge, takes the hooks back out of Claude Code's settings and deletes clack's files.

## Without the installer

On any system with Python 3.8+ or Node 18+, clone this repo and run the bridge from it:

```sh
git clone https://github.com/kyuripark9/Keyboard clack && cd clack
python3 bridge/clack-bridge.py --install   # connect Claude Code
python3 bridge/clack-bridge.py             # run it (or: node bridge/clack-bridge.js), then open http://localhost:4545
```
