# clack on the Chrome Web Store

Everything the [developer dashboard](https://chrome.google.com/webstore/devconsole) asks for, in the order of its tabs.
The same zip and text work for [Edge Add-ons](https://partner.microsoft.com/dashboard/microsoftedge/overview).

- **Package:** `bash store/pack.sh` makes `store/clack-extension-<version>.zip`, the extension with clack inside
  (`extension/build.sh`). Every later upload needs a higher `version` in `extension/manifest.json`.
- **Pictures:** `python3 store/shots.py` renders `screenshot-1.png` to `-3.png` (1280×800) and `promo-tile.png`
  (440×280) from `frame.html`, with the real clack in the side panel.
- **Privacy policy:** https://kyuripark9.github.io/Keyboard/privacy.html (`site/privacy.html`), which has to be live
  before you submit.

## Store listing

**Description**

```
clack gives your hands something to do while claude.ai or ChatGPT writes an answer, and lets go of you the moment it's done.

Click clack's ring in the toolbar and it opens in your browser's side panel, beside the chat. Send a prompt and clack wakes up as the answer starts. Move your cursor across it: every step clicks, pops or squishes, and draws its own picture. When the answer is done, the picture fades to grey and the sound stops, even if you keep playing. That's your cue to go back and read it, and when you come back, clack shows how quickly you went.

Ten materials, each with its own sound and picture:
• Crunchy Slime: crumple a sheet of stitches
• Cyanotype: expose white dots on blue
• Bubble Wrap: pop hills on a blue contour map
• Wax Ball: press the lime squares down into dots
• Thocky Keys: heat holes into thermal colors
• Chewy Jellies: squish jellies and peel them apart
• Pudding: tap soft jellies till they jiggle
• Soap Cutting: shave paths through halftone soap
• Squeaky Snow: crunch boot prints into fresh snow
• Sugar Slime: rake furrows through the sugar down to the blue

No score and no streak, so nothing keeps you there. Every sound is made live in your browser, and your keyboard plays too.

Private by design: on claude.ai and chatgpt.com, clack only checks whether the chat is writing an answer, by its stop button. It doesn't read your messages or the answers, and it sends nothing anywhere. Your count and settings stay in your browser.

clack is an independent project, not affiliated with Anthropic or OpenAI.
```

| Field | Value |
|---|---|
| Category | Lifestyle › Just for Fun |
| Language | English |
| Store icon | `extension/icons/128.png` |
| Screenshots | `store/screenshot-1.png`, `-2.png`, `-3.png` |
| Small promo tile | `store/promo-tile.png` |
| Homepage URL | https://kyuripark9.github.io/Keyboard/ |
| Support URL | https://github.com/kyuripark9/Keyboard/issues |
| Mature content | No |

## Privacy

**Single purpose**

```
clack is a sound toy in the browser's side panel to play with while claude.ai or ChatGPT writes an answer. It wakes up when an answer starts and fades out when the answer is done, so you go back and read it.
```

**Permission justifications**

`sidePanel`
```
clack runs in the browser's side panel, beside the chat. Clicking clack's toolbar icon opens it there and clicking it again closes it.
```

`scripting`
```
When clack is installed or updated, claude.ai and ChatGPT tabs that are already open don't have its content script yet. On install, background.js calls chrome.scripting.executeScript once to add watch.js (the same file as the content script) to those tabs, so they don't need a reload. It isn't used for anything else.
```

Host permissions
```
https://claude.ai/* and https://chatgpt.com/*: watch.js runs there to tell whether the chat is writing an answer (whether its stop button is showing by the message box) and tells clack's side panel when that starts and stops. It reads nothing else on the page and sends nothing off the device.
```

**Remote code:** No, I am not using remote code. If asked to explain:

```
All of the extension's JavaScript is in the package, clack included (clack.html and clack.js, shown in the side panel). The only thing it loads from the internet is clack's fonts, a stylesheet from Google Fonts.
```

**Data usage:** tick none of the data types (clack collects nothing and nothing leaves the device), then tick all three
certifications (no selling or transferring data, no use unrelated to the single purpose, no use for creditworthiness).

**Privacy policy URL:** https://kyuripark9.github.io/Keyboard/privacy.html

## Distribution

Free, Public, all regions.

## Test instructions

```
No login is needed for clack itself.
1. Pin clack and click its icon: clack opens in the side panel. Move the pointer over it to play; the arrows at the bottom change the material. Its line reads "waits with claude.ai and chatgpt".
2. Open chatgpt.com (it works signed out) or claude.ai in the same window and send a prompt. While the answer is being written, the line reads "ChatGPT writing · 0:05" with a pulsing dot.
3. When the answer is done, the line reads "answer ready · go back" and over five seconds the picture fades to grey and the sound stops.
Sound starts after the first click or key press in the panel, as browsers require.
```
