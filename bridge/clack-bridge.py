#!/usr/bin/env python3
"""
clack-bridge (Python): tells clack when your coding agent starts and stops working.
Same behaviour as clack-bridge.js, for Macs without Node. Standard library only.

Claude Code hooks POST to this server:
  UserPromptSubmit -> /start   (you handed off a task: the wait begins)
  Stop             -> /done    (the agent finished: go back)
  StopFailure      -> /done    (the agent stopped on an error)
  Notification     -> /done    (the agent needs you, e.g. a permission prompt)
  SessionEnd       -> /end     (the session closed: its wait is over, with nothing to go back to)

In the Claude app's Code tab, Claude Code reports a permission prompt 6 s late, so the bridge also reads the app's log
for the moment it shows one.

Several sessions can work at once: any one finishing calls you back, and the wait goes on while the others work.

Usage:
  python3 clack-bridge.py            start on port 4545
  python3 clack-bridge.py --port N   start on another port
  python3 clack-bridge.py --hooks    print the hooks block for ~/.claude/settings.json
  python3 clack-bridge.py --install  add the hooks to ~/.claude/settings.json for every session
  python3 clack-bridge.py --autostart     macOS: run in the background and start at login
  python3 clack-bridge.py --no-autostart  macOS: undo --autostart
  python3 clack-bridge.py --uninstall-hooks  take the hooks back out of ~/.claude/settings.json
"""
import json, os, queue, re, sys, threading, time
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

args = sys.argv[1:]
PORT = int(args[args.index('--port') + 1]) if '--port' in args else int(os.environ.get('CLACK_PORT', 4545))
HERE = os.path.dirname(os.path.abspath(__file__))
# installed, the page sits next to the bridge; in a clone of the repo, it is the repo's own index.html one folder up
PAGE = next((p for p in (os.path.join(HERE, 'index.html'), os.path.join(HERE, '..', 'index.html')) if os.path.exists(p)), os.path.join(HERE, 'index.html'))

# the app: a manifest and icons, so Chrome, Edge or Safari can install clack as its own window with a Dock icon
ICONS = ('icon-192.png', 'icon-512.png', 'apple-touch-icon.png', 'favicon-32.png')
MANIFEST = json.dumps({
    'name': 'clack', 'short_name': 'clack', 'id': '/', 'start_url': '/', 'scope': '/',
    'display': 'standalone', 'background_color': '#f4f5f7', 'theme_color': '#2c62fb',
    'description': 'Ten materials to press while your agent works. clack lets go of you when it is done.',
    'icons': [{'src': '/icon-192.png', 'sizes': '192x192', 'type': 'image/png', 'purpose': 'any maskable'},
              {'src': '/icon-512.png', 'sizes': '512x512', 'type': 'image/png', 'purpose': 'any maskable'}],
}).encode()
APP_TAGS = (b'<link rel="manifest" href="/manifest.webmanifest">\n<link rel="icon" href="/favicon-32.png" sizes="32x32">\n'
            b'<link rel="apple-touch-icon" href="/apple-touch-icon.png">\n<meta name="theme-color" content="#2c62fb">\n'
            b'<meta name="apple-mobile-web-app-title" content="clack">')


def hooks_block(port):
    def entry(route):
        cmd = f'curl -s --max-time 1 -X POST --data-binary @- http://localhost:{port}/{route} >/dev/null 2>&1 || true'
        return [{'hooks': [{'type': 'command', 'command': cmd}]}]
    # Notification only for permission prompts: Claude Code also notifies after 60s of idle input, which isn't a call back
    notify = [{'matcher': 'permission_prompt', 'hooks': entry('done')[0]['hooks']}]
    return {'hooks': {'UserPromptSubmit': entry('start'), 'Stop': entry('done'), 'StopFailure': entry('done'),
                      'Notification': notify, 'SessionEnd': entry('end')}}


if '--hooks' in args:
    print(json.dumps(hooks_block(PORT), indent=2))
    sys.exit(0)

AGENT_LABEL = 'ink.clack.bridge'
AGENT_PLIST = os.path.expanduser(f'~/Library/LaunchAgents/{AGENT_LABEL}.plist')
# launchd runs the bridge from Application Support, as macOS keeps background programs out of ~/Documents
APP_DIR = os.path.expanduser('~/Library/Application Support/clack')

if '--autostart' in args or '--no-autostart' in args:
    import plistlib, shutil, subprocess, socket
    if sys.platform != 'darwin':
        print('--autostart is for macOS')
        sys.exit(1)
    domain = f'gui/{os.getuid()}'
    subprocess.run(['launchctl', 'bootout', domain, AGENT_PLIST], capture_output=True)
    if '--no-autostart' in args:
        for p in (AGENT_PLIST,):
            if os.path.exists(p):
                os.remove(p)
        shutil.rmtree(APP_DIR, ignore_errors=True)
        print('clack-bridge no longer starts at login, and the background copy is stopped')
        sys.exit(0)
    with socket.socket() as s:
        busy = s.connect_ex(('127.0.0.1', PORT)) == 0
    if busy:
        print(f'Something is already using port {PORT}. If it is clack-bridge running in a terminal, stop it with Ctrl+C and run this again')
        sys.exit(1)
    os.makedirs(APP_DIR, exist_ok=True)
    # the installer puts the files straight into APP_DIR, and then there is nothing to copy
    if os.path.realpath(HERE) != os.path.realpath(APP_DIR):
        for name in ('clack-bridge.py',) + ICONS:
            shutil.copy2(os.path.join(HERE, name), os.path.join(APP_DIR, name))
        shutil.copy2(PAGE, os.path.join(APP_DIR, 'index.html'))
    log = os.path.expanduser('~/Library/Logs/clack-bridge.log')
    # launchd doesn't create missing folders, and won't start the bridge without its log's
    os.makedirs(os.path.dirname(log), exist_ok=True)
    os.makedirs(os.path.dirname(AGENT_PLIST), exist_ok=True)
    with open(AGENT_PLIST, 'wb') as f:
        plistlib.dump({
            'Label': AGENT_LABEL,
            'ProgramArguments': [sys.executable, '-u', os.path.join(APP_DIR, 'clack-bridge.py'), '--port', str(PORT)],
            'RunAtLoad': True, 'KeepAlive': True, 'ThrottleInterval': 10,
            'StandardOutPath': log, 'StandardErrorPath': log,
        }, f)
    r = subprocess.run(['launchctl', 'bootstrap', domain, AGENT_PLIST], capture_output=True, text=True)
    if r.returncode:
        print(f'launchctl could not start it: {r.stderr.strip() or r.returncode}')
        sys.exit(1)
    for _ in range(30):
        time.sleep(0.2)
        with socket.socket() as s:
            if s.connect_ex(('127.0.0.1', PORT)) == 0:
                break
    else:
        print(f'It was installed but did not answer on port {PORT}; see {log}')
        sys.exit(1)
    print(f'clack-bridge now runs in the background and starts at login: http://localhost:{PORT}')
    print(f'log: {log}  ·  after changing files here, run --autostart again to update the background copy')
    sys.exit(0)

def is_clack_hook(h):
    c = h.get('command', '')
    return 'curl' in c and '--data-binary @-' in c and ('/start' in c or '/done' in c or '/end' in c) and 'localhost:' in c


if '--uninstall-hooks' in args:
    # takes clack's hooks back out of ~/.claude/settings.json and leaves every other setting as it was
    path = os.path.expanduser('~/.claude/settings.json')
    try:
        with open(path) as f:
            settings = json.load(f)
    except (FileNotFoundError, ValueError):
        print('no clack hooks to remove')
        sys.exit(0)
    hooks, removed = settings.get('hooks') or {}, 0
    for event in list(hooks):
        kept = []
        for e in hooks[event]:
            inner = [h for h in e.get('hooks', []) if not is_clack_hook(h)]
            removed += len(e.get('hooks', [])) - len(inner)
            if inner:
                kept.append({**e, 'hooks': inner})
        if kept:
            hooks[event] = kept
        else:
            del hooks[event]
    if not hooks:
        settings.pop('hooks', None)
    if removed:
        with open(path, 'w') as f:
            json.dump(settings, f, indent=2, ensure_ascii=False)
            f.write('\n')
    print(f'removed {removed} clack hooks from {path}' if removed else 'no clack hooks to remove')
    sys.exit(0)

if '--install' in args:
    # merges clack's hooks into ~/.claude/settings.json for every Claude Code session, keeping everything else there
    # and backing the file up first; running it again changes nothing
    path = os.path.expanduser('~/.claude/settings.json')
    try:
        with open(path) as f:
            text = f.read()
        settings = json.loads(text) if text.strip() else {}
    except FileNotFoundError:
        text, settings = None, {}
    except ValueError as e:
        print(f'{path} is not valid JSON ({e}); fix it first, nothing was changed')
        sys.exit(1)
    hooks = settings.setdefault('hooks', {})
    added = 0
    for event, entries in hooks_block(PORT)['hooks'].items():
        have = hooks.setdefault(event, [])
        for entry in entries:
            cmd = entry['hooks'][0]['command']
            if any(h.get('command') == cmd for e in have for h in e.get('hooks', [])):
                continue
            have.append(entry)
            added += 1
    if not added:
        print(f'clack hooks are already in {path}')
        sys.exit(0)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # adding hooks a newer clack brings keeps the backup from before clack's first ones
    if text is not None and not os.path.exists(path + '.before-clack'):
        with open(path + '.before-clack', 'w') as f:
            f.write(text)
    with open(path, 'w') as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print(f'added {added} clack hooks to {path}' + (f' (backup: {path}.before-clack)' if text is not None else ''))
    sys.exit(0)

lock = threading.RLock()  # re-entrant: broadcast() runs inside handlers that already hold it
clients = set()            # one queue per open clack tab
working = {}               # each session the agent is working in: since when, when you last prompted it, its transcript
state = {'phase': 'idle', 'at': int(time.time() * 1000), 'sessions': [], 'working': 0, 'since': None}
# background work that is the agent's own and wakes it when it ends. A monitor (the comment watch every published
# artifact keeps, say) waits on other people and can run all day, so a turn that leaves only that behind is done
AGENT_WORK = ('shell', 'subagent', 'workflow', 'MCP task', 'cloud session')


def settle(now, kind):
    # the wait goes on while any session still works, so one finishing doesn't end the others' wait
    state.update(phase='wait' if working else 'done' if kind == 'done' else 'idle', at=now, sessions=sorted(working),
                 working=len(working), since=min((w['since'] for w in working.values()), default=None))


def tagged(event):
    # every event says how many sessions are still working, and since when the longest of them has been
    return {**event, 'working': state['working'], 'since': state['since']}


def tail(w):
    """the last lines of a session's transcript"""
    try:
        with open(w['transcript'], 'rb') as f:
            f.seek(0, 2)
            f.seek(max(0, f.tell() - 65536))
            return f.read().decode('utf-8', 'replace').splitlines()
    except (OSError, TypeError, KeyError):
        return []


def interrupted(w):
    """Esc stops the agent without a Stop hook; its transcript then ends on the interruption, after your last prompt."""
    for line in reversed(tail(w)):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if e.get('type') not in ('user', 'assistant') or e.get('isSidechain'):
            continue
        content = (e.get('message') or {}).get('content')
        texts = [content] if isinstance(content, str) else [c.get('text', '') for c in content or [] if isinstance(c, dict)]
        if not any(str(t).startswith('[Request interrupted by user') for t in texts):
            return False
        try:
            at = datetime.strptime(e['timestamp'], '%Y-%m-%dT%H:%M:%S.%f%z').timestamp() * 1000
        except (KeyError, ValueError):
            return False
        return at > w['prompted']
    return False


def watch():
    # no hook reports Esc, so every few seconds the transcripts show which sessions were stopped that way
    while True:
        time.sleep(5)
        with lock:
            gone = [s for s, w in working.items() if interrupted(w)]
            if not gone:
                continue
            now = int(time.time() * 1000)
            for s in gone:
                del working[s]
            settle(now, 'end')
            event = tagged({'type': 'tally', 'at': now, 'session': gone[0], 'reason': 'interrupt'})
            broadcast(event)
            log(event, len(clients))

# the Claude app's Code tab runs Claude Code too, but tells it about a permission prompt 6 s late, as the app answers some
# asks for its own tools itself. The app logs each prompt it does show, the moment it shows it
APP_LOG = os.path.expanduser('~/Library/Logs/Claude/main.log')
APP_ASK = re.compile(r'Emitted tool permission request \S+ for (\S+) in session ')


def entries(w):
    for line in tail(w):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if isinstance(e, dict):
            yield e


def from_app(w):
    # Claude Code writes where it was started from into every transcript line
    if 'app' not in w:
        point = next((e['entrypoint'] for e in entries(w) if e.get('entrypoint')), None)
        if point:
            w['app'] = str(point).startswith('claude-desktop')
    return w.get('app', False)


def waiting_on(w):
    """the tools the session called that have no result yet"""
    calls = {}
    for e in entries(w):
        if e.get('isSidechain'):
            continue
        for c in (e.get('message') or {}).get('content') or []:
            if isinstance(c, dict) and c.get('type') == 'tool_use':
                calls[c.get('id')] = c.get('name')
            elif isinstance(c, dict) and c.get('type') == 'tool_result':
                calls.pop(c.get('tool_use_id'), None)
    return set(calls.values())


def asked(tool):
    with lock:
        apps = [s for s, w in working.items() if from_app(w)]
        # with several sessions working in the app, the one waiting on that tool is the one asking
        if len(apps) > 1:
            apps = [s for s in apps if tool in waiting_on(working[s])]
        # still unsure which: Claude Code's own notice comes 6 s later and tells
        if len(apps) != 1:
            return
        now = int(time.time() * 1000)
        del working[apps[0]]
        settle(now, 'done')
        event = tagged({'type': 'done', 'at': now, 'session': apps[0], 'reason': 'Notification', 'auto': False})
        broadcast(event)
        log(event, len(clients))


def watch_app():
    f, ino, rest = None, None, b''
    while True:
        time.sleep(0.25)
        try:
            st = os.stat(APP_LOG)
            # the app starts a new log when one fills up; the first time round only what comes next counts
            if f is None or st.st_ino != ino or st.st_size < f.tell():
                first = ino is None
                if f:
                    f.close()
                f, ino, rest = open(APP_LOG, 'rb'), st.st_ino, b''
                if first:
                    f.seek(0, 2)
            chunk = f.read()
        except (OSError, ValueError):
            continue
        lines = (rest + chunk).split(b'\n')
        rest = lines.pop()
        for line in lines:
            m = APP_ASK.search(line.decode('utf-8', 'replace'))
            if m:
                asked(m.group(1))

CORS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Private-Network': 'true',
}


def broadcast(event):
    with lock:
        for q in list(clients):
            q.put(event)


def log(e, n):
    if e['type'] == 'hold':
        what = f"agent still running: {e['reason']}"
    elif e['type'] == 'tally':
        what = 'agent stopped with Esc' if e['reason'] == 'interrupt' else 'agent closed'
    elif e['type'] == 'start':
        what = 'agent working'
    else:
        what = {'Notification': 'agent needs you', 'StopFailure': 'agent stopped on an error'}.get(e['reason'], 'agent done')
    busy = f"{state['working']} working · " if state['working'] else ''
    print(f"{time.strftime('%I:%M:%S %p')}  {what}  ({busy}{n} clack tab{'' if n == 1 else 's'} listening)", flush=True)


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *a):
        pass

    def send(self, code, headers=None, body=b''):
        self.send_response(code)
        for k, v in {**CORS, **(headers or {})}.items():
            self.send_header(k, v)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_OPTIONS(self):
        self.send(204)

    def do_GET(self):
        path = self.path.split('?')[0]
        if path in ('/', '/index.html'):
            try:
                with open(PAGE, 'rb') as f:
                    body = f.read()
            except OSError:
                return self.send(500, {'Content-Type': 'text/plain'}, b'index.html is missing next to clack-bridge.py')
            # served from here, clack can be installed as an app with its own window and Dock icon
            body = body.replace(b'</title>', b'</title>\n' + APP_TAGS, 1)
            return self.send(200, {'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store'}, body)
        if path == '/manifest.webmanifest':
            return self.send(200, {'Content-Type': 'application/manifest+json', 'Cache-Control': 'no-store'}, MANIFEST)
        if path.lstrip('/') in ICONS:
            try:
                with open(os.path.join(HERE, path.lstrip('/')), 'rb') as f:
                    return self.send(200, {'Content-Type': 'image/png', 'Cache-Control': 'max-age=86400'}, f.read())
            except OSError:
                return self.send(404, {'Content-Type': 'text/plain'}, b'not found')
        if path == '/status':
            with lock:
                body = json.dumps({**state, 'clients': len(clients)}).encode()
            return self.send(200, {'Content-Type': 'application/json'}, body)
        if path == '/events':
            return self.stream()
        self.send(404, {'Content-Type': 'text/plain'}, b'not found')

    def stream(self):
        self.close_connection = True
        self.send_response(200)
        for k, v in {**CORS, 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-store', 'Connection': 'close'}.items():
            self.send_header(k, v)
        self.end_headers()
        q = queue.Queue()
        with lock:
            hello = {'type': 'hello', **state}
            clients.add(q)
        try:
            self.wfile.write(f'retry: 2000\ndata: {json.dumps(hello)}\n\n'.encode())
            self.wfile.flush()
            while True:
                try:
                    e = q.get(timeout=15)
                    self.wfile.write(f'data: {json.dumps(e)}\n\n'.encode())
                except queue.Empty:
                    self.wfile.write(b': ping\n\n')
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass
        finally:
            with lock:
                clients.discard(q)

    def do_POST(self):
        path = self.path.split('?')[0]
        if path not in ('/start', '/done', '/end'):
            return self.send(404, {'Content-Type': 'text/plain'}, b'not found')
        n = int(self.headers.get('Content-Length') or 0)
        try:
            hook = json.loads(self.rfile.read(n) or b'{}') if n else {}
        except ValueError:
            hook = {}
        session = str(hook.get('session_id') or 'default')
        kind = path[1:]
        now = int(time.time() * 1000)
        if DEBUG:
            record(kind, hook)
        # Claude resuming on its own when a background task finishes isn't you handing off something new
        auto = kind == 'start' and str(hook.get('prompt', '')).lstrip().startswith('<task-notification>')
        # Claude ending its turn with its own background work still running isn't done: it will wake again by itself
        bg = [t for t in hook.get('background_tasks') or []
              if t.get('status') in ('running', 'pending') and t.get('type') in AGENT_WORK]
        with lock:
            if kind == 'end':
                # a session closed (or cleared) mid-turn: you're already at it, so its wait just ends
                if working.pop(session, None) is None:
                    return self.send(204)
                settle(now, kind)
                event = tagged({'type': 'tally', 'at': now, 'session': session, 'reason': 'SessionEnd'})
                broadcast(event)
                log(event, len(clients))
                return self.send(204)
            stop = hook.get('hook_event_name') == 'Stop'
            # a session already running when the bridge started (or when its hooks were added) was never seen to
            # start: its first Stop shows it was working all along, so it's taken up from there
            adopt = kind == 'done' and stop and session not in working
            # any other "done" for a session that wasn't working (an idle reminder) is nothing to report
            if kind == 'done' and session not in working and not adopt:
                return self.send(204)
            if auto and session in working:
                return self.send(204)
            w = working.get(session) or {'since': now, 'prompted': now}
            w['transcript'] = hook.get('transcript_path') or w.get('transcript')
            if kind == 'start' and not auto:
                w['prompted'] = now
            working[session] = w
            settle(now, 'start')
            if adopt:
                broadcast(tagged({'type': 'start', 'at': now, 'session': session, 'reason': 'Stop', 'auto': True}))
            if kind == 'done' and bg:
                log({'type': 'hold', 'reason': ', '.join(t.get('description') or t.get('command') or 'task' for t in bg)}, len(clients))
                return self.send(204)
            if kind == 'done':
                del working[session]
                settle(now, kind)
            event = tagged({'type': kind, 'at': now, 'session': session, 'reason': hook.get('hook_event_name') or kind, 'auto': auto})
            count = len(clients)
        broadcast(event)
        log(event, count)
        self.send(204)


DEBUG = '--debug' in args
DEBUG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'hook-debug.jsonl')


def record(kind, hook):
    """--debug: keep each hook's payload and the tail of its transcript, to see what a real session sends."""
    entry = {'t': time.strftime('%H:%M:%S'), 'route': kind, 'hook': hook, 'tail': []}
    path = hook.get('transcript_path')
    if path:
        try:
            with open(os.path.expanduser(path), 'rb') as f:
                f.seek(0, 2)
                start = max(0, f.tell() - 60000)
                f.seek(start)
                lines = f.read().decode('utf-8', 'replace').splitlines()
                lines = (lines[1:] if start else lines)[-12:]  # past the start, the first line is cut
            for line in lines:
                try:
                    entry['tail'].append(json.loads(line))
                except ValueError:
                    entry['tail'].append(line[:2000])
        except OSError as e:
            entry['tail'] = [f'could not read transcript: {e}']
    with open(DEBUG_FILE, 'a') as f:
        f.write(json.dumps(entry, ensure_ascii=False) + '\n')


class Server(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


try:
    srv = Server(('127.0.0.1', PORT), Handler)
except OSError:
    print(f'Port {PORT} is busy. Try: python3 clack-bridge.py --port {PORT + 1}')
    sys.exit(1)
print(f'clack is listening at http://localhost:{PORT}', flush=True)
print(f'Hooks not set up yet? Run: python3 {os.path.basename(__file__)} --hooks', flush=True)
if DEBUG:
    print(f'debug: recording every hook to {DEBUG_FILE}', flush=True)
threading.Thread(target=watch, daemon=True).start()
threading.Thread(target=watch_app, daemon=True).start()
try:
    srv.serve_forever()
except KeyboardInterrupt:
    print('\nclack-bridge stopped')
