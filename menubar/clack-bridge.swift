// clack's bridge, inside the menu bar app: the same as bridge/clack-bridge.py, so clack downloaded as an app needs
// nothing else on the Mac (no Python, no Command Line Tools). It serves clack itself at http://localhost:4545, hears
// Claude Code's hooks and pushes what they say to every clack that's open over Server-Sent Events (/events), the ring
// in the menu bar among them. It only listens on 127.0.0.1, so nothing leaves your Mac.
//
//   UserPromptSubmit -> /start   (you handed off a task: the wait begins)
//   Stop             -> /done    (the agent finished: go back)
//   StopFailure      -> /done    (the agent stopped on an error)
//   Notification     -> /done    (the agent needs you, e.g. a permission prompt)
//   SessionEnd       -> /end     (the session closed: its wait is over, with nothing to go back to)
//
// In the Claude app's Code tab, Claude Code reports a permission prompt 6 s late, so it also reads the app's log for
// the moment it shows one. Several sessions can work at once: any one finishing calls you back, and the wait goes on
// while the others work.
import Foundation
import JavaScriptCore

final class BridgeServer {
  let port: Int
  init(port: Int) { self.port = port }

  // the app: a manifest and icons, so Chrome, Edge or Safari can install clack as its own window with a Dock icon.
  // build.sh puts the page and the icons in the app's Resources
  static let icons = ["icon-192.png", "icon-512.png", "apple-touch-icon.png", "favicon-32.png"]
  static let manifest = Data("""
  {"name":"clack","short_name":"clack","id":"/","start_url":"/","scope":"/","display":"standalone",\
  "background_color":"#f4f5f7","theme_color":"#2c62fb",\
  "description":"Ten materials to press while your agent works. clack lets go of you when it is done.",\
  "icons":[{"src":"/icon-192.png","sizes":"192x192","type":"image/png","purpose":"any maskable"},\
  {"src":"/icon-512.png","sizes":"512x512","type":"image/png","purpose":"any maskable"}]}
  """.utf8)
  static let appTags = Data("""

  <link rel="manifest" href="/manifest.webmanifest">
  <link rel="icon" href="/favicon-32.png" sizes="32x32">
  <link rel="apple-touch-icon" href="/apple-touch-icon.png">
  <meta name="theme-color" content="#2c62fb">
  <meta name="apple-mobile-web-app-title" content="clack">
  """.utf8)
  static let cors = [
    "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type", "Access-Control-Allow-Private-Network": "true",
  ]

  // background work that is the agent's own and wakes it when it ends. A monitor (the comment watch every published
  // artifact keeps, say) waits on other people and can run all day, so a turn that leaves only that behind is done
  static let agentWork: Set<String> = ["shell", "subagent", "workflow", "MCP task", "cloud session"]
  // a shell can also be a server that never ends (the dev server it started for you, say), so a turn that leaves only
  // shells behind and doesn't wake again within ten minutes is done after all
  static let holdMs: Int64 = 10 * 60 * 1000

  // each session the agent is working in: since when, when you last prompted it, its transcript, since when only a
  // shell of its own has kept it going, and whether it runs in the Claude app
  struct Work { var since, prompted: Int64; var transcript: String?; var held: Int64 = 0; var app: Bool? }

  // an open clack: the events still to send it, and a signal for each
  private final class Client { var queue: [Data] = []; let ready = DispatchSemaphore(value: 0) }

  // re-entrant: an event is sent to every clack from inside what already holds it
  private let lock = NSRecursiveLock()
  private var clients: [Client] = []
  private var working: [String: Work] = [:]
  private var state: [String: Any] = ["phase": "idle", "at": now(), "sessions": [String](), "working": 0, "since": NSNull(), "prompted": NSNull()]

  static func now() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

  private func locked<T>(_ f: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return f()
  }

  // false when the port is taken (by a bridge started from Terminal, say), and clack then listens to that one
  func start() -> Bool {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { return false }
    var on: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<Int32>.size))
    var addr = sockaddr_in()
    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = in_port_t(UInt16(port).bigEndian)
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")
    let bound = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
    }
    guard bound == 0, listen(fd, 64) == 0 else {
      close(fd)
      return false
    }
    // one thread for each connection, like the Python bridge: a few clacks listening, and a hook now and then
    Thread.detachNewThread { [self] in
      while true {
        let c = accept(fd, nil, nil)
        guard c >= 0 else {
          Thread.sleep(forTimeInterval: 0.05)
          continue
        }
        Thread.detachNewThread { self.serve(c) }
      }
    }
    Thread.detachNewThread { [self] in watch() }
    Thread.detachNewThread { [self] in watchApp() }
    return true
  }

  // MARK: HTTP

  private struct Request {
    var method = "", path = "", body = Data()

    init?(_ fd: Int32) {
      var data = Data(), buf = [UInt8](repeating: 0, count: 65536)
      let gap = Data("\r\n\r\n".utf8)
      while data.range(of: gap) == nil {
        let n = recv(fd, &buf, buf.count, 0)
        guard n > 0, data.count < 1 << 16 else { return nil }
        data.append(buf, count: n)
      }
      let end = data.range(of: gap)!
      let lines = String(decoding: data[..<end.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
      let first = lines[0].split(separator: " ")
      guard first.count >= 2 else { return nil }
      method = String(first[0])
      path = String(first[1].split(separator: "?", omittingEmptySubsequences: false)[0])
      var length = 0, expect = false
      for line in lines.dropFirst() {
        let kv = line.split(separator: ":", maxSplits: 1)
        guard kv.count == 2 else { continue }
        let key = kv[0].lowercased(), value = kv[1].trimmingCharacters(in: .whitespaces)
        if key == "content-length" { length = Int(value) ?? 0 }
        if key == "expect" { expect = value.lowercased() == "100-continue" }
      }
      // curl waits a second for this before it sends a long prompt, and its hook gives up after one
      if expect { _ = BridgeServer.write(fd, Data("HTTP/1.1 100 Continue\r\n\r\n".utf8)) }
      body = Data(data[end.upperBound...])
      while body.count < length {
        let n = recv(fd, &buf, min(buf.count, length - body.count), 0)
        guard n > 0, body.count < 1 << 26 else { return nil }
        body.append(buf, count: n)
      }
    }
  }

  @discardableResult
  static func write(_ fd: Int32, _ data: Data) -> Bool {
    data.withUnsafeBytes { raw in
      var off = 0
      while off < raw.count {
        let n = Darwin.send(fd, raw.baseAddress! + off, raw.count - off, 0)
        if n < 0 && errno == EINTR { continue }
        if n <= 0 { return false }
        off += n
      }
      return true
    }
  }

  private func respond(_ fd: Int32, _ code: Int, _ headers: [String: String] = [:], _ body: Data = Data()) {
    let reason = [200: "OK", 204: "No Content", 404: "Not Found", 500: "Internal Server Error"][code] ?? "OK"
    var head = "HTTP/1.1 \(code) \(reason)\r\n"
    for (k, v) in BridgeServer.cors.merging(headers, uniquingKeysWith: { $1 }) { head += "\(k): \(v)\r\n" }
    head += "Content-Length: \(body.count)\r\nConnection: close\r\n\r\n"
    BridgeServer.write(fd, Data(head.utf8) + body)
  }

  private func text(_ fd: Int32, _ code: Int, _ s: String) { respond(fd, code, ["Content-Type": "text/plain"], Data(s.utf8)) }

  private func serve(_ fd: Int32) {
    defer { close(fd) }
    var one: Int32 = 1, tv = timeval(tv_sec: 10, tv_usec: 0)
    // a clack that went away fails the next write instead of ending the app, and one that stops reading is let go
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    guard let req = Request(fd) else { return }
    let name = String(req.path.dropFirst())
    switch (req.method, req.path) {
    case ("OPTIONS", _):
      respond(fd, 204)
    case ("GET", "/"), ("GET", "/index.html"):
      guard let url = Bundle.main.url(forResource: "index", withExtension: "html"), var body = try? Data(contentsOf: url) else {
        return text(fd, 500, "index.html is missing from clack.app")
      }
      // served from here, clack can be installed as an app with its own window and Dock icon
      if let r = body.range(of: Data("</title>".utf8)) { body.insert(contentsOf: BridgeServer.appTags, at: r.upperBound) }
      respond(fd, 200, ["Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store"], body)
    case ("GET", "/manifest.webmanifest"):
      respond(fd, 200, ["Content-Type": "application/manifest+json", "Cache-Control": "no-store"], BridgeServer.manifest)
    case ("GET", _) where BridgeServer.icons.contains(name):
      guard let url = Bundle.main.url(forResource: name, withExtension: nil), let body = try? Data(contentsOf: url) else {
        return text(fd, 404, "not found")
      }
      respond(fd, 200, ["Content-Type": "image/png", "Cache-Control": "max-age=86400"], body)
    case ("GET", "/status"):
      let body = locked { BridgeServer.json(state.merging(["clients": clients.count]) { $1 }) }
      respond(fd, 200, ["Content-Type": "application/json"], body)
    case ("GET", "/events"):
      stream(fd)
    case ("POST", "/start"), ("POST", "/done"), ("POST", "/end"):
      let hook = (try? JSONSerialization.jsonObject(with: req.body)) as? [String: Any] ?? [:]
      locked { heard(name, hook) }
      respond(fd, 204)
    default:
      text(fd, 404, "not found")
    }
  }

  private func stream(_ fd: Int32) {
    var head = "HTTP/1.1 200 OK\r\n"
    for (k, v) in BridgeServer.cors { head += "\(k): \(v)\r\n" }
    head += "Content-Type: text/event-stream\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
    let client = Client()
    let hello = locked {
      clients.append(client)
      return BridgeServer.json(state.merging(["type": "hello"]) { $1 })
    }
    defer { locked { clients.removeAll { $0 === client } } }
    guard BridgeServer.write(fd, Data(head.utf8) + Data("retry: 2000\ndata: ".utf8) + hello + Data("\n\n".utf8)) else { return }
    while true {
      var out = Data(": ping\n\n".utf8)
      if client.ready.wait(timeout: .now() + 15) == .success {
        out = Data("data: ".utf8) + locked { client.queue.removeFirst() } + Data("\n\n".utf8)
      }
      guard BridgeServer.write(fd, out) else { return }
    }
  }

  static func json(_ o: Any) -> Data { (try? JSONSerialization.data(withJSONObject: o)) ?? Data("{}".utf8) }

  // MARK: the agent (everything from here on runs holding the lock)

  private func settle(_ now: Int64, _ kind: String) {
    // the wait goes on while any session still works, so one finishing doesn't end the others' wait
    let since = working.values.map(\.since).min(), prompted = working.values.map(\.prompted).max()
    state = ["phase": !working.isEmpty ? "wait" : kind == "done" ? "done" : "idle", "at": now, "sessions": working.keys.sorted(),
             "working": working.count, "since": since.map { $0 as Any } ?? NSNull(), "prompted": prompted.map { $0 as Any } ?? NSNull()]
  }

  // every event says how many sessions are still working, since when the longest of them has been, and when you
  // last handed one of them something, and goes to every clack that's open
  private func emit(_ event: [String: Any]) {
    var e = event
    for k in ["working", "since", "prompted"] { e[k] = state[k] }
    let data = BridgeServer.json(e)
    for c in clients {
      c.queue.append(data)
      c.ready.signal()
    }
  }

  private func heard(_ kind: String, _ hook: [String: Any]) {
    let session = (hook["session_id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "default"
    let now = BridgeServer.now()
    // Claude resuming on its own when a background task finishes isn't you handing off something new
    let auto = kind == "start" && (hook["prompt"] as? String ?? "").drop(while: \.isWhitespace).hasPrefix("<task-notification>")
    // Claude ending its turn with its own background work still running isn't done: it will wake again by itself
    let bg = (hook["background_tasks"] as? [[String: Any]] ?? []).filter {
      ["running", "pending"].contains($0["status"] as? String) && BridgeServer.agentWork.contains($0["type"] as? String ?? "")
    }
    if kind == "end" {
      // a session closed (or cleared) mid-turn: you're already at it, so its wait just ends
      guard working.removeValue(forKey: session) != nil else { return }
      settle(now, kind)
      return emit(["type": "tally", "at": now, "session": session, "reason": "SessionEnd"])
    }
    // a session already running when the bridge started (or when its hooks were added) was never seen to start: its
    // first Stop shows it was working all along, so it's taken up from there
    let adopt = kind == "done" && hook["hook_event_name"] as? String == "Stop" && working[session] == nil
    // any other "done" for a session that wasn't working (an idle reminder) is nothing to report
    if kind == "done" && working[session] == nil && !adopt { return }
    if auto && working[session] != nil {
      // it woke again, so whatever it left running wasn't a server after all
      working[session]?.held = 0
      return
    }
    var w = working[session] ?? Work(since: now, prompted: now)
    if let t = hook["transcript_path"] as? String, !t.isEmpty { w.transcript = t }
    if kind == "start" && !auto { w.prompted = now }
    w.held = kind == "done" && !bg.isEmpty && bg.allSatisfy({ $0["type"] as? String == "shell" }) ? now : 0
    working[session] = w
    settle(now, "start")
    if adopt { emit(["type": "start", "at": now, "session": session, "reason": "Stop", "auto": true]) }
    if kind == "done" && !bg.isEmpty { return }
    if kind == "done" {
      working[session] = nil
      settle(now, kind)
    }
    emit(["type": kind, "at": now, "session": session, "reason": hook["hook_event_name"] as? String ?? kind, "auto": auto])
  }

  // the last lines of a session's transcript, each that reads as an object
  private func entries(_ w: Work) -> [[String: Any]] {
    guard let path = w.transcript, let f = FileHandle(forReadingAtPath: path) else { return [] }
    defer { try? f.close() }
    guard let end = try? f.seekToEnd(), (try? f.seek(toOffset: end > 65536 ? end - 65536 : 0)) != nil,
          let data = try? f.readToEnd() else { return [] }
    return data.split(separator: UInt8(ascii: "\n")).compactMap { (try? JSONSerialization.jsonObject(with: Data($0))) as? [String: Any] }
  }

  private static let stamp: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  // Esc stops the agent without a Stop hook; its transcript then ends on the interruption, after your last prompt
  private func interrupted(_ w: Work) -> Bool {
    for e in entries(w).reversed() {
      guard ["user", "assistant"].contains(e["type"] as? String), e["isSidechain"] as? Bool != true else { continue }
      let content = (e["message"] as? [String: Any])?["content"]
      let texts = content is String ? [content as! String]
        : (content as? [Any] ?? []).compactMap { ($0 as? [String: Any]).map { $0["text"] as? String ?? "" } }
      guard texts.contains(where: { $0.hasPrefix("[Request interrupted by user") }),
            let ts = e["timestamp"] as? String, let at = BridgeServer.stamp.date(from: ts) else { return false }
      return Int64(at.timeIntervalSince1970 * 1000) > w.prompted
    }
    return false
  }

  private func watch() {
    // no hook reports Esc, so every few seconds the transcripts show which sessions were stopped that way
    while true {
      Thread.sleep(forTimeInterval: 5)
      locked {
        let now = BridgeServer.now()
        // and which turns left only a shell behind that has run too long to be anything but a server
        for (s, w) in working where w.held > 0 && now - w.held >= BridgeServer.holdMs {
          working[s] = nil
          settle(now, "done")
          emit(["type": "done", "at": now, "session": s, "reason": "Stop", "held": true])
        }
        let gone = working.filter { interrupted($0.value) }.map(\.key)
        guard let first = gone.first else { return }
        for s in gone { working[s] = nil }
        settle(now, "end")
        emit(["type": "tally", "at": now, "session": first, "reason": "interrupt"])
      }
    }
  }

  // MARK: the Claude app

  // the Claude app's Code tab runs Claude Code too, but tells it about a permission prompt 6 s late, as the app answers
  // some asks for its own tools itself. The app logs each prompt it does show, the moment it shows it
  private static let appLog = NSHomeDirectory() + "/Library/Logs/Claude/main.log"
  private static let appAsk = try! NSRegularExpression(pattern: #"Emitted tool permission request \S+ for (\S+) in session "#)

  // Claude Code writes where it was started from into every transcript line
  private func fromApp(_ s: String) -> Bool {
    guard let w = working[s] else { return false }
    if w.app == nil, let point = entries(w).lazy.compactMap({ $0["entrypoint"] as? String }).first(where: { !$0.isEmpty }) {
      working[s]?.app = point.hasPrefix("claude-desktop")
    }
    return working[s]?.app ?? false
  }

  // the tools the session called that have no result yet
  private func waitingOn(_ w: Work) -> Set<String> {
    var calls: [String: String] = [:]
    for e in entries(w) where e["isSidechain"] as? Bool != true {
      for case let c as [String: Any] in (e["message"] as? [String: Any])?["content"] as? [Any] ?? [] {
        if c["type"] as? String == "tool_use", let id = c["id"] as? String { calls[id] = c["name"] as? String ?? "" }
        if c["type"] as? String == "tool_result", let id = c["tool_use_id"] as? String { calls[id] = nil }
      }
    }
    return Set(calls.values)
  }

  private func asked(_ tool: String) {
    locked {
      var apps = Array(working.keys).filter { fromApp($0) }
      // with several sessions working in the app, the one waiting on that tool is the one asking
      if apps.count > 1 { apps = apps.filter { waitingOn(working[$0]!).contains(tool) } }
      // still unsure which: Claude Code's own notice comes 6 s later and tells
      guard apps.count == 1 else { return }
      let now = BridgeServer.now()
      working[apps[0]] = nil
      settle(now, "done")
      emit(["type": "done", "at": now, "session": apps[0], "reason": "Notification", "auto": false])
    }
  }

  private func watchApp() {
    var f: FileHandle?, ino: UInt64?, rest = Data()
    while true {
      Thread.sleep(forTimeInterval: 0.25)
      var st = stat()
      guard stat(BridgeServer.appLog, &st) == 0 else { continue }
      // the app starts a new log when one fills up; the first time round only what comes next counts
      if f == nil || UInt64(st.st_ino) != ino || UInt64(st.st_size) < (f.flatMap { try? $0.offset() } ?? 0) {
        let first = ino == nil
        try? f?.close()
        f = FileHandle(forReadingAtPath: BridgeServer.appLog)
        ino = f == nil ? nil : UInt64(st.st_ino)
        rest = Data()
        if first { _ = try? f?.seekToEnd() }
      }
      guard let chunk = try? f?.readToEnd(), !chunk.isEmpty else { continue }
      var lines = (rest + chunk).split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false)
      rest = Data(lines.removeLast())
      for line in lines {
        let s = String(decoding: line, as: UTF8.self)
        if let m = BridgeServer.appAsk.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), let r = Range(m.range(at: 1), in: s) {
          asked(String(s[r]))
        }
      }
    }
  }
}

// MARK: Claude Code's settings

// clack's hooks in ~/.claude/settings.json, as clack-bridge.py --install and --uninstall-hooks put them in and take them
// out. JavaScript does the editing, since its JSON keeps the order of everything else in the file, which Foundation's
// doesn't; the file is backed up before clack first changes it
enum ClaudeHooks {
  static let folder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude")
  static let settings = folder.appendingPathComponent("settings.json")

  private static let script = """
  (text, port, mode) => {
    const post = route => `curl -s --max-time 1 -X POST --data-binary @- http://localhost:${port}/${route} >/dev/null 2>&1 || true`;
    const entry = route => [{ hooks: [{ type: 'command', command: post(route) }] }];
    // Notification only for permission prompts: Claude Code also notifies after 60s of idle input, which isn't a call back
    const block = { UserPromptSubmit: entry('start'), Stop: entry('done'), StopFailure: entry('done'),
      Notification: [{ matcher: 'permission_prompt', hooks: [{ type: 'command', command: post('done') }] }], SessionEnd: entry('end') };
    let settings;
    try { settings = text && text.trim() ? JSON.parse(text) : {}; } catch (e) { return { error: String(e.message || e) }; }
    if (!settings || typeof settings !== 'object' || Array.isArray(settings)) return { error: 'it is not a JSON object' };
    const hooks = settings.hooks && typeof settings.hooks === 'object' ? settings.hooks : {};
    const has = (ev, cmd) => (hooks[ev] || []).some(e => (e.hooks || []).some(h => h.command === cmd));
    if (mode === 'check') return { connected: Object.entries(block).every(([ev, es]) => has(ev, es[0].hooks[0].command)) };
    let n = 0;
    if (mode === 'install') {
      settings.hooks = hooks;
      for (const [ev, es] of Object.entries(block)) for (const e of es) {
        if (has(ev, e.hooks[0].command)) continue;
        (hooks[ev] = hooks[ev] || []).push(e);
        n++;
      }
    } else {
      const ours = h => { const c = String(h.command || ''); return c.includes('curl') && c.includes('--data-binary @-') &&
        (c.includes('/start') || c.includes('/done') || c.includes('/end')) && c.includes('localhost:'); };
      for (const ev of Object.keys(hooks)) {
        const kept = [];
        for (const e of hooks[ev] || []) {
          const inner = (e.hooks || []).filter(h => !ours(h));
          n += (e.hooks || []).length - inner.length;
          if (inner.length) kept.push({ ...e, hooks: inner });
        }
        if (kept.length) hooks[ev] = kept; else delete hooks[ev];
      }
      if (!Object.keys(hooks).length) delete settings.hooks;
    }
    return { changed: n, text: n ? JSON.stringify(settings, null, 2) + '\\n' : null };
  }
  """

  private static func run(_ mode: String, _ port: Int, _ file: URL) -> [String: Any] {
    let text = try? String(contentsOf: file, encoding: .utf8)
    guard let ctx = JSContext(), let fn = ctx.evaluateScript(script),
          let r = fn.call(withArguments: [text.map { $0 as Any } ?? NSNull(), port, mode])?.toDictionary() as? [String: Any] else {
      return ["error": "clack could not read it"]
    }
    return r
  }

  static func connected(_ port: Int, _ file: URL = settings) -> Bool { run("check", port, file)["connected"] as? Bool ?? false }

  // nil when it's done, otherwise what went wrong
  static func connect(_ port: Int, _ file: URL = settings) -> String? { change("install", port, file) }
  static func disconnect(_ port: Int, _ file: URL = settings) -> String? { change("uninstall", port, file) }

  private static func change(_ mode: String, _ port: Int, _ file: URL) -> String? {
    let r = run(mode, port, file)
    if let error = r["error"] as? String { return "\(file.path) can't be read as settings (\(error)), so clack left it as it was." }
    guard let text = r["text"] as? String else { return nil }
    let fm = FileManager.default, backup = URL(fileURLWithPath: file.path + ".before-clack")
    do {
      try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      // adding hooks a newer clack brings keeps the backup from before clack's first ones
      if mode == "install", fm.fileExists(atPath: file.path), !fm.fileExists(atPath: backup.path) {
        try fm.copyItem(at: file, to: backup)
      }
      try text.write(to: file, atomically: true, encoding: .utf8)
    } catch {
      return "clack could not change \(file.path): \(error.localizedDescription)"
    }
    return nil
  }
}
