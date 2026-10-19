# Clack

A stress-relief sound toy. Move your cursor across the screen and every step clicks, pops or squishes, and each sound draws its own picture to play with.

## The 9 sounds

| # | Sound | Picture |
|---|-------|---------|
| 01 | Bubble Wrap | The sheet as a blue contour map on cream paper: each bubble is a hill of rings, and a pop flattens it and sends a ripple through its neighbours before it slowly refills |
| 02 | Crunchy Slime | A sheet of + stitches that crumples like paper: each step folds it along a straight crease into flat, angular facets that slowly flatten out |
| 03 | Cyanotype | A cobalt print in camouflage patches: grainy solid blue next to a white halftone dot screen. The cursor exposes the paper as it passes: dots bloom open along its path, swell into solid white where it goes over the same spot again, twinkle with little glints, and quickly sink back into the blue; the sound is a soft, airy brush with a few faint grains |
| 04 | Wax Ball | The 왁뿌볼 (wax-crushing ball): a sheet of hard periwinkle wax over soft cobalt clay. Each step cracks the shell into polygon flakes that split outward from the step, so the clay shows through the cracks; the cursor squeezes the clay up between the flakes, and the wax slowly sets smooth again. The sound is a dry snap, a rush of brittle crackles and a soft squish |
| 05 | Thocky Keys | A cream keyboard on an ink-black desk. Each step bottoms out the key under it: the cap sinks with a springy bounce and glows cobalt, and the plate flexes so its neighbours dip with it. Your real keyboard presses the matching keycap. The sound is a deep, muffled thock with a light tick as the key springs back. Narrow screens get a compact board |
| 06 | Tanghulu | A glossy sheet of candy glass with bands of shine. Each step bites a star of straight, kinked fractures into it that runs back to the last bite, so a swipe leaves one connected crack; chips of sugar flick out and fall, and the cracks melt away. The sound is a bright crack, glassy tinks and a crunch |
| 07 | Pudding | Rows of caramel puddings on little plates. Each step taps one: it squashes, springs back taller and jiggles, and the wobble ripples out through its neighbours a beat later. The sound is a soft wet slap and a low, shivering wobble |
| 08 | Soap Cutting | A cream bar of soap with a periwinkle core, scored into tiny cubes. Each step shaves a strip along the stroke: the cubes tumble off and fall out of the frame, and the bar slowly sets smooth again. The sound is a crisp rising shave and the patter of falling cubes |
| 09 | Snow | A field of fresh snow with wind-packed drifts. Each stride crunches a boot print into it, left and right in turn along the cursor's path, with glitter twinkling around; new snow slowly fills the prints back in. The sound is a dull, dense crunch with a faint cold squeak |

Sounds 04–09 follow the trend of Roblox ASMR tower obbies such as 왁뿌볼 타워 and Keyboard ASMR Towers, where every step lands on a different satisfying material.

- **Just move**: sounds play as your cursor moves. On touch screens, drag a finger. The page always opens on 01 Bubble Wrap.
- **Matching cursor**: a ring cursor that takes on each picture's own color.
- Your real keyboard plays too (letters, digits, space, enter), and the left and right arrows switch sounds. Settings and your clack count are saved in the browser.

All sounds are synthesized live with the Web Audio API, so there are no audio files. They are tuned for ASMR: soft attacks, rounded filters, small crisp details and a little reverb. The palette comes from one moodboard: cobalt, periwinkle, grey and warm paper, and ink.

## Run locally

It's a static page with no build step. Open `index.html`, or serve the folder:

```sh
python3 -m http.server 8000   # http://localhost:8000
```

## Deploy to GitHub Pages

In the repo, go to Settings → Pages, choose "Deploy from a branch", and pick this branch with the `/ (root)` folder.
