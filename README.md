# Clack Keyboard

A stress-relief keyboard toy. Glide your mouse across a giant keyboard and every key you pass clicks.

## Features

- **Glide or Tap**: keys play as your cursor passes over them, or only when you click or tap. On touch screens, swipe a finger across the keys.
- **ASMR & fidget sounds**: Wax Ball (crack the wax shell, then squish), Pop It, Squishy, Crunchy Slime, Kinetic Sand, Bubble Wrap, and Shuffle (a different sound on every key). Keys deform, dimple or crack to match.
- **Classic sounds**: Clicky, Tactile, Thock, Typewriter, Wood Block, Marimba, 8-Bit, and Voice (reads each key out loud).
- **Keyboard styles**: Retro (beige board on a black plate with clear caps, bare switches and doodle legends), Typewriter (glass keys in chrome rings), Thrift Mix (mismatched vintage caps), Calculator (two-tone keys under a segment LCD that shows what you type), and Modern with 7 colorways.
- **Custom cursor**: 9 shapes, any color, adjustable size, sparkle trail.
- Your real keyboard plays too. Settings and your clack count are saved in the browser.

All sounds are synthesized live with the Web Audio API, so there are no audio files. Voice mode uses the browser's speech synthesis.

## Run locally

It's a static page with no build step. Open `index.html`, or serve the folder:

```sh
python3 -m http.server 8000   # http://localhost:8000
```

## Deploy to GitHub Pages

In the repo, go to Settings → Pages, choose "Deploy from a branch", and pick this branch with the `/ (root)` folder.
