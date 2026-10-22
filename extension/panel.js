// Which clack the side panel opens: the one installed on this computer when its bridge answers, since that one follows
// your agent through Claude Code's hooks; otherwise the web version, where a demo agent stands in
const LOCAL = 'http://localhost:4545/', WEB = 'https://kyuripark9.github.io/Keyboard/play/';
const frame = document.getElementById('clack'), off = document.getElementById('off');

async function local() {
  try {
    const r = await fetch(LOCAL + 'status', { cache: 'no-store', signal: AbortSignal.timeout(800) });
    return r.ok;
  } catch (e) {
    return false;
  }
}

async function open() {
  off.hidden = true;
  if (await local()) frame.src = LOCAL;
  else if (navigator.onLine) frame.src = WEB;
  else off.hidden = false;
}

document.getElementById('retry').addEventListener('click', open);
open();
