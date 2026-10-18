# Clack Keyboard

A stress-relief keyboard toy. Glide your mouse across a giant keyboard and every key you pass clicks.

## Features

- **Glide or Tap**: keys play as your cursor passes over them, or only when you click or tap. On touch screens, swipe a finger across the keys.
- **10 sounds**: Clicky (blue switches), Tactile (browns), Thock (lubed linears), Typewriter (with a bell on Enter), Bubble Wrap, Wood Block (+1 zen counter), Marimba (every key is in tune), 8-Bit, Voice (reads each key out loud: A, B, C), and Shuffle (a different sound per key).
- **7 keycap colorways**: Auto (follows light/dark mode), Cloud, Midnight, Mint Chip, Retro, Cherry Blossom, Blackout.
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
