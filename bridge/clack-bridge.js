#!/usr/bin/env node
/*
  clack-bridge: tells clack when your coding agent starts and stops working.

  Claude Code hooks POST to this server:
    UserPromptSubmit -> /start   (you handed off a task: the wait begins)
    Stop             -> /done    (the agent finished: go back)
    StopFailure      -> /done    (the agent stopped on an error)
    Notification     -> /done    (the agent needs you, e.g. a permission prompt)
    SessionEnd       -> /end     (the session closed: its wait is over, with nothing to go back to)

  In the Claude app's Code tab, Claude Code reports a permission prompt 6 s late, so the bridge also reads the app's log
  for the moment it shows one.

  Several sessions can work at once: any one finishing calls you back, and the wait goes on while the others work.

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
const os = require('os');
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
  return { hooks: { UserPromptSubmit: entry('start'), Stop: entry('done'), StopFailure: entry('done'),
    Notification: [{ matcher: 'permission_prompt', hooks: [{ type: 'command', command: post('done') }] }],
    SessionEnd: entry('end') } };
}

if (args.includes('--hooks')) {
  process.stdout.write(JSON.stringify(hooksBlock(PORT), null, 2) + '\n');
  process.exit(0);
}

const clients = new Set();
let state = { phase: 'idle', at: Date.now(), sessions: [], working: 0, since: null };
// each session the agent is working in: since when, when you last prompted it, its transcript
const working = new Map();
// background work that is the agent's own and wakes it when it ends. A monitor (the comment watch every published
// artifact keeps, say) waits on other people and can run all day, so a turn that leaves only that behind is done
const AGENT_WORK = ['shell', 'subagent', 'workflow', 'MCP task', 'cloud session'];

function broadcast(event) {
  const line = `data: ${JSON.stringify(event)}\n\n`;
  for (const res of clients) res.write(line);
}

// the wait goes on while any session still works, so one finishing doesn't end the others' wait
function settle(at, type) {
  const since = [...working.values()].map(w => w.since);
  state = { phase: working.size ? 'wait' : type === 'done' ? 'done' : 'idle', at, sessions: [...working.keys()],
    working: working.size, since: since.length ? Math.min(...since) : null };
}
// every event says how many sessions are still working, and since when the longest of them has been
const tagged = event => ({ ...event, working: state.working, since: state.since });

// the last lines of a session's transcript
function tail(w) {
  try {
    const fd = fs.openSync(w.transcript, 'r');
    try {
      const size = fs.fstatSync(fd).size, n = Math.min(size, 65536), buf = Buffer.alloc(n);
      fs.readSync(fd, buf, 0, n, size - n);
      return buf.toString('utf8').split('\n');
    } finally { fs.closeSync(fd); }
  } catch (e) { return []; }
}

// Esc stops the agent without a Stop hook; its transcript then ends on the interruption, after your last prompt
function interrupted(w) {
  const lines = tail(w);
  for (let i = lines.length - 1; i >= 0; i--) {
    let e; try { e = JSON.parse(lines[i]); } catch (err) { continue; }
    if ((e.type !== 'user' && e.type !== 'assistant') || e.isSidechain) continue;
    const c = (e.message || {}).content;
    const texts = typeof c === 'string' ? [c] : (Array.isArray(c) ? c : []).map(x => (x && x.text) || '');
    if (!texts.some(t => String(t).startsWith('[Request interrupted by user'))) return false;
    return Date.parse(e.timestamp) > w.prompted;
  }
  return false;
}

// no hook reports Esc, so every few seconds the transcripts show which sessions were stopped that way
setInterval(() => {
  const gone = [...working].filter(([, w]) => interrupted(w)).map(([s]) => s);
  if (!gone.length) return;
  gone.forEach(s => working.delete(s));
  settle(Date.now(), 'end');
  const event = tagged({ type: 'tally', at: state.at, session: gone[0], reason: 'interrupt' });
  broadcast(event);
  log(event);
}, 5000).unref();

// the Claude app's Code tab runs Claude Code too, but tells it about a permission prompt 6 s late, as the app answers some
// asks for its own tools itself. The app logs each prompt it does show, the moment it shows it
const APP_LOG = path.join(os.homedir(), 'Library', 'Logs', 'Claude', 'main.log');
const APP_ASK = /Emitted tool permission request \S+ for (\S+) in session /;

function entries(w) {
  return tail(w).map(line => { try { return JSON.parse(line); } catch (e) { return null; } }).filter(e => e && typeof e === 'object');
}

// Claude Code writes where it was started from into every transcript line
function fromApp(w) {
  if (!('app' in w)) {
    const e = entries(w).find(e => e.entrypoint);
    if (e) w.app = String(e.entrypoint).startsWith('claude-desktop');
  }
  return w.app === true;
}

// the tools the session called that have no result yet
function waitingOn(w) {
  const calls = new Map();
  for (const e of entries(w)) {
    if (e.isSidechain) continue;
    const c = (e.message || {}).content;
    for (const x of Array.isArray(c) ? c : []) {
      if (x && x.type === 'tool_use') calls.set(x.id, x.name);
      else if (x && x.type === 'tool_result') calls.delete(x.tool_use_id);
    }
  }
  return new Set(calls.values());
}

function asked(tool) {
  let apps = [...working].filter(([, w]) => fromApp(w)).map(([s]) => s);
  // with several sessions working in the app, the one waiting on that tool is the one asking
  if (apps.length > 1) apps = apps.filter(s => waitingOn(working.get(s)).has(tool));
  // still unsure which: Claude Code's own notice comes 6 s later and tells
  if (apps.length !== 1) return;
  const now = Date.now();
  working.delete(apps[0]);
  settle(now, 'done');
  const event = tagged({ type: 'done', at: now, session: apps[0], reason: 'Notification', auto: false });
  broadcast(event);
  log(event);
}

let appLog = null;
setInterval(() => {
  try {
    const st = fs.statSync(APP_LOG);
    // the app starts a new log when one fills up; the first time round only what comes next counts
    if (!appLog || st.ino !== appLog.ino || st.size < appLog.at) {
      appLog = { ino: st.ino, at: appLog ? 0 : st.size, rest: '' };
    }
    if (st.size <= appLog.at) return;
    const fd = fs.openSync(APP_LOG, 'r');
    const buf = Buffer.alloc(st.size - appLog.at);
    try { fs.readSync(fd, buf, 0, buf.length, appLog.at); } finally { fs.closeSync(fd); }
    appLog.at = st.size;
    const lines = (appLog.rest + buf.toString('utf8')).split('\n');
    appLog.rest = lines.pop();
    for (const line of lines) {
      const m = APP_ASK.exec(line);
      if (m) asked(m[1]);
    }
  } catch (e) {}
}, 250).unref();

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

  if (req.method === 'POST' && (url.pathname === '/start' || url.pathname === '/done' || url.pathname === '/end')) {
    const hook = await readBody(req);
    const session = String(hook.session_id || 'default');
    const type = url.pathname.slice(1);
    const now = Date.now();
    // Claude resuming on its own when a background task finishes isn't you handing off something new
    const auto = type === 'start' && String(hook.prompt || '').trimStart().startsWith('<task-notification>');
    // Claude ending its turn with its own background work still running isn't done: it will wake again by itself
    const bg = (hook.background_tasks || []).filter(t => t && (t.status === 'running' || t.status === 'pending') && AGENT_WORK.includes(t.type));
    const skip = () => { res.writeHead(204, CORS); res.end(); };
    if (type === 'end') {
      // a session closed (or cleared) mid-turn: you're already at it, so its wait just ends
      if (!working.delete(session)) return skip();
      settle(now, type);
      const event = tagged({ type: 'tally', at: now, session, reason: 'SessionEnd' });
      broadcast(event);
      log(event);
      return skip();
    }
    const stop = hook.hook_event_name === 'Stop';
    // a session already running when the bridge started (or when its hooks were added) was never seen to start: its
    // first Stop shows it was working all along, so it's taken up from there
    const adopt = type === 'done' && stop && !working.has(session);
    // any other "done" for a session that wasn't working (an idle reminder) is nothing to report
    if (type === 'done' && !working.has(session) && !adopt) return skip();
    if (auto && working.has(session)) return skip();
    const w = working.get(session) || { since: now, prompted: now };
    w.transcript = hook.transcript_path || w.transcript;
    if (type === 'start' && !auto) w.prompted = now;
    working.set(session, w);
    settle(now, 'start');
    if (adopt) broadcast(tagged({ type: 'start', at: now, session, reason: 'Stop', auto: true }));
    if (type === 'done' && bg.length) {
      log({ type: 'hold', at: now, reason: bg.map(t => t.description || t.command || 'task').join(', ') });
      return skip();
    }
    if (type === 'done') { working.delete(session); settle(now, type); }
    const event = tagged({ type, at: now, session, reason: hook.hook_event_name || type, auto });
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
  const what = e.type === 'hold' ? `agent still running: ${e.reason}`
    : e.type === 'tally' ? (e.reason === 'interrupt' ? 'agent stopped with Esc' : 'agent closed')
    : e.type === 'start' ? 'agent working'
    : ({ Notification: 'agent needs you', StopFailure: 'agent stopped on an error' })[e.reason] || 'agent done';
  const busy = state.working ? `${state.working} working · ` : '';
  console.log(`${t}  ${what}  (${busy}${clients.size} clack tab${clients.size === 1 ? '' : 's'} listening)`);
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
