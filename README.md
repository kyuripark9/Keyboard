# Clack

A stress-relief sound toy. Move your cursor across the screen and every step clicks, pops or squishes, and each sound draws its own picture to play with.

## The 6 sounds

| # | Sound | Picture |
|---|-------|---------|
| 01 | Wax Ball | Black-and-white cells whose touching lines melt into goo; steps crack big cells into small ones and pop the small ones |
| 02 | Bubble Wrap | A sheet of bubbles that pop flat and slowly refill |
| 03 | Squishy | Soft blue blobs that squash and slowly rise back |
| 04 | Crunchy Slime | A sheet of + stitches that crumples like paper: each step folds it along a straight crease into flat, angular facets that slowly flatten out |
| 05 | Kinetic Sand | Letters that pour down into a pile |
| 06 | Typewriter | Stamped type that wears off and drifts down the page |

- **Glide or Tap**: play as your cursor moves, or only while you click, tap or drag. On touch screens, drag a finger.
- **Custom cursor**: 9 shapes, any color, adjustable size and trail.
- Your real keyboard plays too (letters, digits, space, enter), and the left and right arrows switch sounds. Settings and your clack count are saved in the browser.

All sounds are synthesized live with the Web Audio API, so there are no audio files. They are tuned for ASMR: soft attacks, rounded filters, small crisp details and a little reverb. The palette comes from one moodboard: cobalt, periwinkle, grey and warm paper, and ink. Wax Ball is the exception: pure black on white, like a gig poster.

## Run locally

It's a static page with no build step. Open `index.html`, or serve the folder:

```sh
python3 -m http.server 8000   # http://localhost:8000
```

## Deploy to GitHub Pages

In the repo, go to Settings → Pages, choose "Deploy from a branch", and pick this branch with the `/ (root)` folder.
