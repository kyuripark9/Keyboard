// clicking clack's ring in the toolbar opens it in the side panel, and clicking it again closes it
chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true }).catch(e => console.error(e));
