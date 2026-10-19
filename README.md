# Clack

A stress-relief sound toy. Move your cursor across the screen and every step clicks, pops or squishes, and each sound draws its own picture to play with.

## The 7 sounds

| # | Sound | Picture |
|---|-------|---------|
| 01 | Wax Ball | Cobalt pebbles printed like a cyanotype: solid cores over pale, grainy, off-register halos; steps crack big pebbles in two and pop the small ones |
| 02 | Bubble Wrap | The sheet as a blue contour map on cream paper: each bubble is a hill of rings, and a pop flattens it and sends a ripple through its neighbours before it slowly refills |
| 03 | Squishy | A wall of puffy white silicone tiles (pairs of balls joined by a pinched neck, in a basket weave); steps squash a ball, which wobbles back and puffs up its partner. The page always opens here |
| 04 | Crunchy Slime | A sheet of + stitches that crumples like paper: each step folds it along a straight crease into flat, angular facets that slowly flatten out |
| 05 | Kinetic Sand | Fine coral lines on grey, a vertical set crossing a slanted one into a glowing moiré; the cursor rakes through them like a finger in sand |
| 06 | Typewriter | Stamped type that wears off and drifts down the page |
| 07 | Pearl | Fine dotted lines on cream paper spiralling into a sinking pearl that follows the cursor; steps spin the vortex and play glassy pentatonic pings |

- **Just move**: sounds play as your cursor moves. On touch screens, drag a finger. The page always opens on 03 Squishy.
- **Custom cursor**: 9 shapes, any color, adjustable size and trail.
- Your real keyboard plays too (letters, digits, space, enter), and the left and right arrows switch sounds. Settings and your clack count are saved in the browser.

All sounds are synthesized live with the Web Audio API, so there are no audio files. They are tuned for ASMR: soft attacks, rounded filters, small crisp details and a little reverb. The palette comes from one moodboard: cobalt, periwinkle, grey and warm paper, and ink.

## Run locally

It's a static page with no build step. Open `index.html`, or serve the folder:

```sh
python3 -m http.server 8000   # http://localhost:8000
```

## Deploy to GitHub Pages

In the repo, go to Settings → Pages, choose "Deploy from a branch", and pick this branch with the `/ (root)` folder.
