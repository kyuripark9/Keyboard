# Clack

A stress-relief sound toy. Move your cursor across the screen and every step clicks, pops or squishes, and each sound draws its own picture to play with.

## The 6 sounds

| # | Sound | Picture |
|---|-------|---------|
| 01 | Wax Ball | Cobalt pebbles printed like a cyanotype: solid cores over pale, grainy, off-register halos; steps crack big pebbles in two and pop the small ones |
| 02 | Bubble Wrap | The sheet as a blue contour map on cream paper: each bubble is a hill of rings, and a pop flattens it and sends a ripple through its neighbours before it slowly refills |
| 03 | Squishy | Grainy black ink blobs with a photocopy texture that squash and wobble back. |
| 04 | Crunchy Slime | A sheet of + stitches that crumples like paper: each step folds it along a straight crease into flat, angular facets that slowly flatten out |
| 05 | Kinetic Sand | Letters that pour down into a pile |
| 06 | Typewriter | Stamped type that wears off and drifts down the page |

- **Just move**: sounds play as your cursor moves. On touch screens, drag a finger. The page always opens on 03 Squishy.
- **Custom cursor**: 9 shapes, any color, adjustable size and trail.
- Your real keyboard plays too (letters, digits, space, enter), and the left and right arrows switch sounds. Settings and your clack count are saved in the browser.

All sounds are synthesized live with the Web Audio API, so there are no audio files. They are tuned for ASMR: soft attacks, rounded filters, small crisp details and a little reverb. The palette comes from one moodboard: cobalt, periwinkle, grey and warm paper, and ink. Squishy is the exception: black toner on white, like a photocopy.

## Run locally

It's a static page with no build step. Open `index.html`, or serve the folder:

```sh
python3 -m http.server 8000   # http://localhost:8000
```

## Deploy to GitHub Pages

In the repo, go to Settings → Pages, choose "Deploy from a branch", and pick this branch with the `/ (root)` folder.
