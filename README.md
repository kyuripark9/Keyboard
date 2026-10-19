# Clack

A stress-relief sound toy. Move your cursor across the screen and every step clicks, pops or squishes, and each sound draws its own picture to play with.

## The 10 sounds

| # | Sound | Picture |
|---|-------|---------|
| 01 | Bubble Wrap | The sheet as a contour map of pale grey rings on mint paper: each bubble is a hill of rings, big droplets of mixed sizes scattered unevenly, stretched and tilted their own ways, with touching ones sharing their outer rings; a pop flattens it and sends a ripple through its neighbours before it slowly refills |
| 02 | Crunchy Slime | A sheet of + stitches that crumples like paper: each step folds it along a straight crease into flat, angular facets that slowly flatten out |
| 03 | Cyanotype | A cobalt print in camouflage patches: grainy solid blue next to a white halftone dot screen. The cursor exposes the paper as it passes: dots bloom open along its path, swell into solid white where it goes over the same spot again, twinkle with little glints, and quickly sink back into the blue; the sound is soft, light foam: a gentle breath of air that swells in and out with a faint sizzle of tiny bubbles |
| 04 | Wax Ball | The 왁뿌볼 (wax-crushing ball)'s shell as a black and white halftone, after a reference image: white squares on a grid that swell into solid white patches and shrink to tiny dots in the dark pools between them, turning from square to diamond as they shrink, while the grid bends in toward the bright patches and the whole print slowly drifts. The cursor presses into it like a thumb into clay: the squares along its path swell into a white ribbon that pulls the grid in after it, each step cracks the chips around it so they twist and wobble back into line, and the ribbon slowly sinks back into the print. The sound is a dry snap, a rush of brittle crackles and a soft squish |
| 05 | Thocky Keys | Light through a perforated sheet, after a photo: pale grey steel that shades to steel blue at the bottom, cut with a grid of round holes scattered like braille. A hole only shows once light comes through it: the cursor shoots a laser along its path that lights the holes near it, each one burning open in a bright flash, its rim glowing orange and throwing a few sparks, then cooling to a soft white glow inside a faint scorch mark. A few seconds after the cursor passes they go dark again, the outer ones first. The sound is a deep, muffled thock with a light tick as the key springs back |
| 06 | Tanghulu | A glossy sheet of candy glass with bands of shine. Each step bites a star of straight, kinked fractures into it that runs back to the last bite, so a swipe leaves one connected crack; chips of sugar flick out and fall, and the cracks melt away. The sound is a muffled snap, a soft crunch of candy and the juicy give of the fruit |
| 07 | Pudding | A soft-focus field of green jelly rounds on cream, every edge blurred as if seen through frosted glass. Every jelly the cursor passes over turns into a red jelly square for a few seconds, then hops back into a green round. Each step taps one: it spreads flat, springs back and jiggles out of shape, and the wobble ripples out through its neighbours a beat later. The sound is a soft wet slap and a low, shivering wobble |
| 08 | Soap Cutting | A bar of soap packed with tiny cream beads over a core of periwinkle ones. Each step shaves a strip along the stroke: its beads tumble off and fall out of the frame, the core shows in the cut, and the beads pop back in one by one as the bar sets again. The sound is a crisp rising shave and the patter of falling beads |
| 09 | Snow | A field of fresh snow with wind-packed drifts. Each stride crunches a boot print into it, left and right in turn along the cursor's path, with glitter twinkling around; new snow slowly fills the prints back in. The sound is a dull, dense crunch with a faint cold squeak |
| 10 | Sugar Slime | Periwinkle slime packed with sugar, printed as a stipple of fine grains. The cursor drags three fingertips through it: each leaves a furrow with the slime it pushed aside heaped along its walls, cobalt grains crowd into the shaded walls and creases, white crystals catch the light on the lit ones, and the slime slowly settles flat again. The sound is a 서걱서걱 (seo-geok) crunch: a soft rasp as the fingers sink in, a dry, sandy grind of sugar grains and a muted squish underneath |

Sounds 04–09 follow the trend of Roblox ASMR tower obbies such as 왁뿌볼 타워 and Keyboard ASMR Towers, where every step lands on a different satisfying material.

- **Just move**: sounds play as your cursor moves. On touch screens, drag a finger. The page always opens on 01 Bubble Wrap.
- **Matching cursor**: a ring cursor that takes on each picture's own color. On 04 Wax Ball's black and white halftone it inverts whatever is under it instead.
- Your real keyboard plays too (letters, digits, space, enter), and the left and right arrows switch sounds. Settings and your clack count are saved in the browser.

All sounds are synthesized live with the Web Audio API, so there are no audio files. They are tuned for ASMR: soft attacks, rounded filters, small crisp details and a little reverb. The palette comes from one moodboard: cobalt, periwinkle, grey and warm paper, and ink. 01 Bubble Wrap, 04 Wax Ball, 05 Thocky Keys and 07 Pudding are the exceptions: each takes its colors from its own reference image (mint and pale grey from a print of pixel squares; black and white from a halftone of rotated squares; silver grey, steel blue and glowing white from a photo of light through a perforated sheet; green, red and cream).

## Run locally

It's a static page with no build step. Open `index.html`, or serve the folder:

```sh
python3 -m http.server 8000   # http://localhost:8000
```

## Deploy to GitHub Pages

In the repo, go to Settings → Pages, choose "Deploy from a branch", and pick this branch with the `/ (root)` folder.
