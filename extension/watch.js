// On claude.ai and ChatGPT: whether the chat is writing an answer. Both swap the send button by the box you type in for
// a stop button while they write, and claude.ai also marks the message it's writing. Each change goes to clack's side
// panel, which wakes clack when an answer starts and lets go of you when it's done
(() => {
  if (window.__clackWatch) return; // put in again by the extension after an update, the first one keeps watching
  window.__clackWatch = true;
  const site = location.hostname.endsWith('claude.ai') ? 'claude.ai' : 'ChatGPT';
  const STOP = 'button[data-testid*="stop" i], button[aria-label*="stop" i], button[aria-label*="중지"]';

  function writing() {
    if (document.querySelector('[data-is-streaming="true"]')) return true;
    // only a stop button by the box you type in, not one for voice or a shared screen elsewhere on the page
    for (const box of document.querySelectorAll('[contenteditable="true"], textarea')) {
      const near = box.closest('form, fieldset') || box.parentElement?.parentElement?.parentElement;
      if (near && near.querySelector(STOP)) return true;
    }
    return false;
  }

  let was = null;
  function check() {
    const now = writing();
    if (now === was) return;
    was = now;
    // the extension reloaded or removed: this page has no one to tell any more
    try { chrome.runtime.sendMessage({ clack: 'chat', writing: now, site }).catch(() => {}); } catch (e) { stop(); }
  }
  // a panel opened after the answer began asks how things stand
  chrome.runtime.onMessage.addListener((m, sender, reply) => { if (m && m.clack === 'ask') reply({ writing: writing(), site }); });

  const seen = new MutationObserver(check);
  seen.observe(document.documentElement, { subtree: true, childList: true, attributes: true, attributeFilter: ['data-is-streaming', 'aria-label', 'data-testid'] });
  const tick = setInterval(check, 1000);
  function stop() { seen.disconnect(); clearInterval(tick); }
  check();
})();
