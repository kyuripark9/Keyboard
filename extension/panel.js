// The side panel plays clack (clack.html, from the extension's own files) and follows claude.ai and ChatGPT for it:
// their tabs tell the panel when an answer starts and ends (watch.js), and the panel passes that on to clack
const CHATS = ['https://claude.ai/*', 'https://chatgpt.com/*'];
const frame = document.getElementById('clack');

// the chats writing an answer, by tab, since when; an answer that pauses for a moment (between a search and the
// writing, say) isn't done, so a stop counts once it has lasted a little while
const writing = new Map(), ending = new Map(), sites = new Map();
const PAUSE_MS = 1500;

// told in clack's words: how many are at work, since when the longest of them, and when the last began
function tell(type, tab, extra) {
  const at = Date.now(), times = [...writing.values()];
  const e = { type, at, session: 'tab-' + tab, working: writing.size, since: times.length ? Math.min(...times) : null,
    prompted: times.length ? Math.max(...times) : null, site: sites.get(tab) || '', ...extra };
  frame.contentWindow?.postMessage({ clack: e }, location.origin);
}

function heard(tab, now, site) {
  sites.set(tab, site);
  if (now) {
    // back at it before the pause ran out: the same answer goes on
    if (ending.has(tab)) {
      clearTimeout(ending.get(tab));
      ending.delete(tab);
      return;
    }
    if (writing.has(tab)) return;
    writing.set(tab, Date.now());
    tell('start', tab, { reason: 'UserPromptSubmit' });
  } else if (writing.has(tab) && !ending.has(tab)) {
    ending.set(tab, setTimeout(() => {
      ending.delete(tab);
      writing.delete(tab);
      tell('done', tab, { reason: 'Stop' });
    }, PAUSE_MS));
  }
}

chrome.runtime.onMessage.addListener((m, sender) => {
  if (m && m.clack === 'chat' && sender.tab) heard(sender.tab.id, !!m.writing, m.site);
});
// a tab closed mid-answer: there's nothing to go back to, so the wait just ends
function gone(tab) {
  if (!writing.has(tab)) return;
  clearTimeout(ending.get(tab));
  ending.delete(tab);
  writing.delete(tab);
  tell('tally', tab, { reason: 'SessionEnd' });
}
chrome.tabs.onRemoved.addListener(tab => gone(tab));
chrome.tabs.onReplaced.addListener((added, removed) => gone(removed));
// and so does one that went off claude.ai and ChatGPT mid-answer (the extension only sees a tab's address on those), or
// that Chrome put to sleep to save memory: no watcher is left in it to say when the answer is done
chrome.tabs.onUpdated.addListener((tab, change, t) => {
  if (writing.has(tab) && !ending.has(tab) && (change.discarded || !t.url)) gone(tab);
});

// clack says when it's ready to listen; then it hears how things stand, asking each chat that's open
addEventListener('message', async m => {
  if (m.source !== frame.contentWindow || !m.data || m.data.clack !== 'ready') return;
  const times = [...writing.values()];
  frame.contentWindow.postMessage({ clack: { type: 'hello', at: Date.now(), phase: times.length ? 'wait' : 'idle',
    working: times.length, since: times.length ? Math.min(...times) : null, prompted: times.length ? Math.max(...times) : null } }, location.origin);
  for (const t of await chrome.tabs.query({ url: CHATS })) {
    chrome.tabs.sendMessage(t.id, { clack: 'ask' }).then(r => r && heard(t.id, !!r.writing, r.site)).catch(() => {});
  }
});
