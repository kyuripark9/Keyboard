#!/usr/bin/env python3
"""Renders the pictures for clack's Chrome Web Store listing from store/frame.html, with nothing but Python and Chrome:

    python3 store/shots.py          ->  store/screenshot-1.png to -3.png (1280x800) and store/promo-tile.png (440x280)

It serves the repo on clack.localhost (so clack doesn't look for its bridge), opens the frame in headless Chrome and
drives it over the DevTools protocol, so the pointer that plays clack in the side panel is a real one. Redo the
pictures when a material's look changes."""
import base64, json, os, shutil, socket, struct, subprocess, sys, tempfile, threading, time, urllib.request
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'store')
CHROME = os.environ.get('CHROME', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
SHOTS = [('1', 'screenshot-1.png', 1280, 800), ('2', 'screenshot-2.png', 1280, 800), ('3', 'screenshot-3.png', 1280, 800),
         ('tile', 'promo-tile.png', 440, 280)]


class Quiet(SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


def free_port():
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


class DevTools:
    """Just enough of a WebSocket client to talk to one Chrome page."""

    def __init__(self, url):
        hostport, path = url[len('ws://'):].split('/', 1)
        host, port = hostport.rsplit(':', 1)
        self.s = socket.create_connection((host, int(port)))
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall((f'GET /{path} HTTP/1.1\r\nHost: {hostport}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
                        f'Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n').encode())
        head = b''
        while b'\r\n\r\n' not in head:
            head += self.s.recv(4096)
        head, self.buf = head.split(b'\r\n\r\n', 1)
        if b' 101 ' not in head.split(b'\r\n', 1)[0]:
            sys.exit('shots: Chrome refused the DevTools connection: ' + head.decode(errors='replace'))
        self.n = 0

    def _read(self, n):
        while len(self.buf) < n:
            chunk = self.s.recv(1 << 20)
            if not chunk:
                sys.exit('shots: Chrome closed the DevTools connection')
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def _frame(self):
        b0, b1 = self._read(2)
        n = b1 & 0x7f
        if n == 126:
            n = struct.unpack('>H', self._read(2))[0]
        elif n == 127:
            n = struct.unpack('>Q', self._read(8))[0]
        return b0, self._read(n)

    def call(self, method, **params):
        self.n += 1
        data = json.dumps({'id': self.n, 'method': method, 'params': params}).encode()
        mask = os.urandom(4)
        n = len(data)
        head = bytes([0x81]) + (bytes([0x80 | n]) if n < 126 else bytes([0xfe]) + struct.pack('>H', n) if n < 65536
                                else bytes([0xff]) + struct.pack('>Q', n))
        self.s.sendall(head + mask + bytes(c ^ mask[i % 4] for i, c in enumerate(data)))
        while True:
            msg = b''
            while True:
                b0, part = self._frame()
                msg += part
                if b0 & 0x80:
                    break
            if not msg.startswith(b'{'):  # a ping, not a reply
                continue
            m = json.loads(msg)
            if m.get('id') == self.n:
                if 'error' in m:
                    sys.exit(f'shots: {method} failed: {m["error"]}')
                return m.get('result', {})

    def js(self, expr):
        return self.call('Runtime.evaluate', expression=expr, returnByValue=True, awaitPromise=True)['result'].get('value')

    def move(self, x, y):
        self.call('Input.dispatchMouseEvent', type='mouseMoved', x=x, y=y)


def play(dt, p):
    """Moves the pointer along the frame's path through clack's panel, at about a hand's speed."""
    pts = [(p['x'] + u * p['w'], p['y'] + v * p['h']) for u, v in p['path']]
    dt.move(*pts[0])
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        steps = max(1, int(((x1 - x0) ** 2 + (y1 - y0) ** 2) ** .5 / 7))
        for i in range(1, steps + 1):
            dt.move(x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps)
            time.sleep(0.012)


def main():
    port = free_port()
    server = ThreadingHTTPServer(('127.0.0.1', port), partial(Quiet, directory=ROOT))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    profile = tempfile.mkdtemp(prefix='clack-shots-')
    debug = free_port()
    chrome = subprocess.Popen([CHROME, '--headless=new', f'--remote-debugging-port={debug}', f'--user-data-dir={profile}',
                               '--no-first-run', '--no-default-browser-check', '--hide-scrollbars', '--mute-audio',
                               '--force-device-scale-factor=1', '--window-size=1280,800', 'about:blank'],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(100):
            try:
                pages = json.load(urllib.request.urlopen(f'http://127.0.0.1:{debug}/json/list'))
                page = next(t for t in pages if t['type'] == 'page')
                break
            except Exception:
                time.sleep(0.1)
        else:
            sys.exit('shots: Chrome did not start')
        dt = DevTools(page['webSocketDebuggerUrl'])
        dt.call('Page.enable')
        for shot, name, w, h in SHOTS:
            dt.call('Emulation.setDeviceMetricsOverride', width=w, height=h, deviceScaleFactor=1, mobile=False)
            dt.call('Page.navigate', url=f'http://clack.localhost:{port}/store/frame.html?shot={shot}')
            time.sleep(0.5)
            for _ in range(200):
                if dt.js('window.isReady && window.isReady()'):
                    break
                time.sleep(0.1)
            else:
                sys.exit(f'shots: shot {shot} never got ready')
            p = dt.js('window.panel ? window.panel() : null')
            if p:
                if p['done']:
                    # the answer finishes and clack lets go, played on as it greys, still reading "answer ready · go back"
                    dt.js('window.finish()')
                    time.sleep(2)
                play(dt, p)
                time.sleep(0.15)
            png = base64.b64decode(dt.call('Page.captureScreenshot', format='png')['data'])
            with open(os.path.join(OUT, name), 'wb') as f:
                f.write(png)
            print('wrote', os.path.relpath(os.path.join(OUT, name), ROOT))
    finally:
        chrome.terminate()
        chrome.wait()
        server.shutdown()
        shutil.rmtree(profile, ignore_errors=True)


if __name__ == '__main__':
    main()
