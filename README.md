# Clack

A stress-relief sound toy. Move your cursor across the screen and every step clicks, pops or squishes, and each sound draws its own picture to play with.

## The 10 sounds

| # | Sound | Picture |
|---|-------|---------|
| 01 | Bubble Wrap | The sheet as a contour map of pale grey rings on mint paper: each bubble is a hill of rings, big droplets of mixed sizes packed close in uneven rows, stretched and tilted their own ways, pressing against each other so their rings meet in creases; a pop flattens it and sends a ripple through its neighbours before it slowly refills |
| 02 | Crunchy Slime | A sheet of + stitches that crumples like paper: each step folds it along a straight crease into flat, angular facets that slowly flatten out |
| 03 | Cyanotype | A cobalt print in camouflage patches: grainy solid blue next to a white halftone dot screen. The cursor exposes the paper as it passes: dots bloom open along its path, swell into solid white where it goes over the same spot again, twinkle with little glints, and quickly sink back into the blue; the sound is soft, light foam: a gentle breath of air that swells in and out with a faint sizzle of tiny bubbles |
| 04 | Wax Ball | The 왁뿌볼 (wax-crushing ball)'s shell as a black and white halftone, after a reference image: big white squares on a grid over black, packed so close that only thin black seams show between them, swelling and easing a little as the print slowly drifts. The cursor presses into it like a thumb into clay: the squares along its path shrink and turn into tiny diamonds, leaving a black trail that pushes the grid aside, each step cracks the chips around it so they twist and wobble back into line, and the squares slowly swell back into place. The sound is a dry snap, a rush of brittle crackles and a soft squish |
| 05 | Thocky Keys | Light through a perforated sheet, after a photo, in the powder blue and cream of a two-tone print: a mottled powder blue sheet that deepens a little toward the bottom, cut with an even grid of round holes. A hole only shows once light comes through it: the cursor shoots a laser along its path that lights the holes near it, each one burning open in a bright flash, its rim glowing golden and throwing a few sparks, then cooling to a soft cream glow inside a faint blue scorch mark. A few seconds after the cursor passes they go dark again, the outer ones first. The sound is a deep, muffled thock with a light tick as the key springs back |
| 06 | Chewy Jellies | Fruit gummies (raspberry, orange, lemon, lime and grape) cut into soft cubes and dusted with sugar, packed into a tray so tight that they press flat against each other and stick where they touch. The cursor catches the gummy under it and drags it along: it squeezes into the one ahead, which flattens and shoves its own neighbours, and pulls away from the one behind, the two stretching a short, chewy neck of jelly between them until it lets go and both spring back with a wobble. Dragged too far, a gummy slips off the cursor and bounces home, where it sticks again to whatever it touches. Each step also presses down on the gummy under it, so it spreads into its neighbours and keeps a dent that fills back in. The sound is firm, chewy jelly squeezed together close to the ear: a soft, round squish with a faint tacky crackle as the surfaces grip and slip (쫀득), and a soft, tacky peel (쩍) each time a neck of jelly lets go |
| 07 | Pudding | A soft-focus field of green jelly rounds on cream, every edge blurred as if seen through frosted glass. Every jelly the cursor passes over turns into a red jelly square for a few seconds, then hops back into a green round. Each step taps one: it spreads flat, springs back and jiggles out of shape, and the wobble ripples out through its neighbours a beat later. The sound is a soft wet slap and a low, shivering wobble |
| 08 | Soap Cutting | A bar of soap crusted all over with tiny flat sky blue beads, after a photo of loose blue beads. Each step sweeps a path along the stroke: its middle comes away clean down to the white soap and its edges thin out into scattered beads, so it fades softly into the rest. The loose beads tumble off and fall off the screen. After a while the path closes in from its edges and the beads pop back one by one as the edges reach them. The sound is a crisp rising shave and the patter of falling beads |
| 09 | Snow | A field of fresh snow with wind-packed drifts. Each stride crunches a boot print into it, left and right in turn along the cursor's path, with glitter twinkling around; new snow slowly fills the prints back in. The sound is a soft step into powder: a hush, a fine, close creak of crystals packing together (뽀드득) and a breath of cold air |
| 10 | Sugar Slime | Periwinkle slime packed with sugar, printed as a stipple of fine grains. The cursor drags three fingertips through it: each leaves a furrow with the slime it pushed aside heaped along its walls, cobalt grains crowd into the shaded walls and creases, white crystals catch the light on the lit ones, and the slime slowly settles flat again. The sound is a gentle 사각사각 (sa-gak): a soft sandy brush as the fingers sweep through, a fine trickle of rolling sugar grains and a muted squish underneath |

Sounds 04–09 follow the trend of Roblox ASMR tower obbies such as 왁뿌볼 타워 and Keyboard ASMR Towers, where every step lands on a different satisfying material.

- **Just move**: sounds play as your cursor moves. On touch screens, drag a finger. The page always opens on 01 Bubble Wrap.
- **Turn the page**: the arrows at the middle of each side of the screen go to the previous and next material, and the number by the logo (clack¹ to clack¹⁰) shows which one you're on. Nothing else sits on the picture: the logo, that number, the clack count and the arrows are drawn right on it in its own ink.
- **The story**: the intro says what the toy is for and how to play, and "Read the story behind it" on the intro opens a case study for portfolio visitors: why it exists, how the cursor plays the screen, the ten materials with what each one looks and sounds like, the process from a clicking keyboard to ten materials (with the ideas that were cut), and the small details. Picking a material there plays it. The copy lives in the `story` markup and the `STORY` table in `index.html`.
- **Matching cursor**: a ring cursor that takes on each picture's own color. On 04 Wax Ball's black and white halftone it inverts whatever is under it instead.
- Your real keyboard plays too (letters, digits, space, enter), and the left and right arrow keys switch sounds. Your clack count is saved in the browser.

All sounds are synthesized live with the Web Audio API, so there are no audio files. They are tuned for ASMR: soft attacks, rounded filters, small crisp details and a little reverb. The palette comes from one moodboard: cobalt, periwinkle, grey and warm paper, and ink. 01 Bubble Wrap, 04 Wax Ball, 05 Thocky Keys, 06 Chewy Jellies, 07 Pudding and 08 Soap Cutting are the exceptions: each takes its colors from its own reference image or subject (mint and pale grey from a print of pixel squares; black and white from a halftone of rotated squares; powder blue and cream from a two-tone print, on a photo of light through a perforated sheet; raspberry, orange, lemon, lime and grape fruit gummies on white sugar; green, red and cream; sky blue beads on white from a photo of loose blue beads).

## Run locally

It's a static page with no build step. Open `index.html`, or serve the folder:

```sh
python3 -m http.server 8000   # http://localhost:8000
```

## Deploy to GitHub Pages

In the repo, go to Settings → Pages, choose "Deploy from a branch", and pick this branch with the `/ (root)` folder.
