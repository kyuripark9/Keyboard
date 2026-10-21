#!/usr/bin/env node
/*
  clack-bridge: tells clack when your coding agent starts and stops working.

  Claude Code hooks POST to this server:
    UserPromptSubmit -> /start   (you handed off a task: the wait begins)
    Stop             -> /done    (the agent finished: go back)
    Notification     -> /done    (the agent needs you, e.g. a permission prompt)

  The server serves clack itself at http://localhost:4545 and pushes those
  moments to the page over Server-Sent Events (/events).
  No dependencies, nothing leaves your machine.

  Usage:
    node clack-bridge.js            start on port 4545
    node clack-bridge.js --port N   start on another port
    node clack-bridge.js --hooks    print the hooks block for ~/.claude/settings.json
*/
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const portArg = args.indexOf('--port');
const PORT = Number(portArg >= 0 ? args[portArg + 1] : process.env.CLACK_PORT) || 4545;
// installed, the page sits next to the bridge; in a clone of the repo, it is the repo's own index.html one folder up
const PAGE = [path.join(__dirname, 'index.html'), path.join(__dirname, '..', 'index.html')].find(p => fs.existsSync(p)) || path.join(__dirname, 'index.html');

// the app: a manifest and icons, so Chrome, Edge or Safari can install clack as its own window with a Dock icon
const ICONS = ['icon-192.png', 'icon-512.png', 'apple-touch-icon.png', 'favicon-32.png'];
const MANIFEST = JSON.stringify({
  name: 'clack', short_name: 'clack', id: '/', start_url: '/', scope: '/',
  display: 'standalone', background_color: '#f4f5f7', theme_color: '#2c62fb',
  description: 'Ten materials to press while your agent works. clack lets go of you when it is done.',
  icons: [{ src: '/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any maskable' },
          { src: '/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any maskable' }],
});
const APP_TAGS = '<link rel="manifest" href="/manifest.webmanifest">\n<link rel="icon" href="/favicon-32.png" sizes="32x32">\n' +
  '<link rel="apple-touch-icon" href="/apple-touch-icon.png">\n<meta name="theme-color" content="#2c62fb">\n' +
  '<meta name="apple-mobile-web-app-title" content="clack">';

function hooksBlock(port) {
  const post = route => `curl -s --max-time 1 -X POST --data-binary @- http://localhost:${port}/${route} >/dev/null 2>&1 || true`;
  const entry = route => [{ hooks: [{ type: 'command', command: post(route) }] }];
  // Notification only for permission prompts: Claude Code also notifies after 60s of idle input, which isn't a call back
  return { hooks: { UserPromptSubmit: entry('start'), Stop: entry('done'),
    Notification: [{ matcher: 'permission_prompt', hooks: [{ type: 'command', command: post('done') }] }] } };
}

if (args.includes('--hooks')) {
  process.stdout.write(JSON.stringify(hooksBlock(PORT), null, 2) + '\n');
  process.exit(0);
}

const clients = new Set();
let state = { phase: 'idle', at: Date.now(), sessions: [] };
const working = new Set();

function broadcast(event) {
  const line = `data: ${JSON.stringify(event)}\n\n`;
  for (const res of clients) res.write(line);
}

function readBody(req) {
  return new Promise(resolve => {
    let body = '';
    req.on('data', c => { body += c; if (body.length > 1e6) req.destroy(); });
    req.on('end', () => { try { resolve(JSON.parse(body || '{}')); } catch (e) { resolve({}); } });
    req.on('error', () => resolve({}));
  });
}

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  // lets a hosted copy of clack reach this server in browsers that ask before a public page talks to localhost
  'Access-Control-Allow-Private-Network': 'true',
};

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  if (req.method === 'OPTIONS') { res.writeHead(204, CORS); return res.end(); }

  if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/index.html')) {
    fs.readFile(PAGE, (err, buf) => {
      if (err) { res.writeHead(500, { 'Content-Type': 'text/plain' }); return res.end('index.html is missing next to clack-bridge.js'); }
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
      // served from here, clack can be installed as an app with its own window and Dock icon
      res.end(buf.toString('utf8').replace('</title>', '</title>\n' + APP_TAGS));
    });
    return;
  }

  if (req.method === 'GET' && url.pathname === '/manifest.webmanifest') {
    res.writeHead(200, { 'Content-Type': 'application/manifest+json', 'Cache-Control': 'no-store' });
    return res.end(MANIFEST);
  }

  if (req.method === 'GET' && ICONS.includes(url.pathname.slice(1))) {
    fs.readFile(path.join(__dirname, url.pathname.slice(1)), (err, buf) => {
      if (err) { res.writeHead(404, { 'Content-Type': 'text/plain' }); return res.end('not found'); }
      res.writeHead(200, { 'Content-Type': 'image/png', 'Cache-Control': 'max-age=86400' });
      res.end(buf);
    });
    return;
  }

  if (req.method === 'GET' && url.pathname === '/events') {
    res.writeHead(200, { ...CORS, 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-store', Connection: 'keep-alive' });
    res.write(`retry: 2000\ndata: ${JSON.stringify({ type: 'hello', ...state })}\n\n`);
    clients.add(res);
    const ping = setInterval(() => res.write(': ping\n\n'), 15000);
    req.on('close', () => { clearInterval(ping); clients.delete(res); });
    return;
  }

  if (req.method === 'GET' && url.pathname === '/status') {
    res.writeHead(200, { ...CORS, 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ ...state, clients: clients.size }));
  }

  if (req.method === 'POST' && (url.pathname === '/start' || url.pathname === '/done')) {
    const hook = await readBody(req);
    const session = String(hook.session_id || 'default');
    const type = url.pathname.slice(1);
    // Claude resuming on its own when a background task finishes isn't you handing off something new
    const auto = type === 'start' && String(hook.prompt || '').trimStart().startsWith('<task-notification>');
    // Claude ending its turn with background tasks still running isn't done: it will wake again by itself
    const bg = (hook.background_tasks || []).filter(t => t && t.status === 'running');
    const skip = () => { res.writeHead(204, CORS); res.end(); };
    const stop = hook.hook_event_name === 'Stop';
    // a session already running when the bridge started (or when its hooks were added) was never seen to start: its
    // first Stop shows it was working all along, so it's taken up from there
    const adopt = type === 'done' && stop && !working.has(session);
    // any other "done" for a session that wasn't working (an idle reminder) is nothing to report
    if (type === 'done' && !working.has(session) && !adopt) return skip();
    const take = () => broadcast({ type: 'start', at: Date.now(), session, reason: 'Stop', auto: true });
    if (type === 'done' && bg.length) {
      if (adopt) { working.add(session); state = { phase: 'wait', at: Date.now(), sessions: [...working] }; take(); }
      log({ type: 'hold', at: Date.now(), reason: bg.map(t => t.description || t.command || 'task').join(', ') });
      return skip();
    }
    if (adopt) take();
    if (auto && working.has(session)) return skip();
    if (type === 'start') working.add(session); else working.delete(session);
    // the wait goes on while any session is still working; any one finishing calls you back
    state = { phase: type === 'start' ? 'wait' : 'done', at: Date.now(), sessions: [...working] };
    const event = { type, at: state.at, session, reason: hook.hook_event_name || type, auto };
    broadcast(event);
    log(event);
    res.writeHead(204, CORS);
    return res.end();
  }

  res.writeHead(404, { ...CORS, 'Content-Type': 'text/plain' });
  res.end('not found');
});

function log(e) {
  const t = new Date(e.at).toLocaleTimeString();
  const what = e.type === 'hold' ? `agent still running: ${e.reason}` : e.type === 'start' ? 'agent working' : e.reason === 'Notification' ? 'agent needs you' : 'agent done';
  console.log(`${t}  ${what}  (${clients.size} clack tab${clients.size === 1 ? '' : 's'} listening)`);
}

server.on('error', err => {
  if (err.code === 'EADDRINUSE') console.error(`Port ${PORT} is busy. Try: node clack-bridge.js --port ${PORT + 1}`);
  else console.error(err);
  process.exit(1);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`clack is listening at http://localhost:${PORT}`);
  console.log(`Hooks not set up yet? Run: node ${path.basename(__filename)} --hooks`);
});
