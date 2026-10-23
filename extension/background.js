// clicking clack's ring in the toolbar opens it in the side panel, and clicking it again closes it
chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true }).catch(e => console.error(e));

// claude.ai and ChatGPT tabs already open when clack is added (or updated) get its watcher too, without a reload
chrome.runtime.onInstalled.addListener(async () => {
  const tabs = await chrome.tabs.query({ url: ['https://claude.ai/*', 'https://chatgpt.com/*'] });
  for (const t of tabs) chrome.scripting.executeScript({ target: { tabId: t.id }, files: ['watch.js'] }).catch(() => {});
});
