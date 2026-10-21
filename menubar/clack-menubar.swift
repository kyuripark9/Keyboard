// clack in the menu bar: its ring stays at the top right of the screen whatever app you're in (Claude, ChatGPT, a
// terminal), shows what your agent is doing, and opens clack under it.
//
//   waiting for the agent (start)  the ring breathes
//   agent done (done)              the ring holds still and its dot fills in
//   bridge offline                 the ring dims
//
// Click it to open clack (http://localhost:4545 in a popover), which stays over your other apps while you work in them
// until you click the ring again or press Esc in it; right-click or Control-click for the menu. The state comes from the bridge's /events stream, the same one the page listens to.
// Build it with build.sh next to this file.
import AppKit
import WebKit

let defaults = UserDefaults.standard
let port = Int(ProcessInfo.processInfo.environment["CLACK_PORT"] ?? "") ?? (defaults.integer(forKey: "port") > 0 ? defaults.integer(forKey: "port") : 4545)
let base = URL(string: "http://localhost:\(port)/")!

enum Phase { case idle, wait, done }

// the ring is drawn here rather than shipped as a picture, as a template image, so macOS inks it for a light or dark
// menu bar; its proportions follow the app icon's, with the dot a little larger to read at this size
enum Ring {
  static let size = NSSize(width: 18, height: 18)
  static let outer: CGFloat = 7.5, line: CGFloat = 1.9, dot: CGFloat = 2.2

  static func image(ring: CGFloat, dot fill: CGFloat) -> NSImage {
    let img = NSImage(size: size, flipped: false) { r in
      let c = NSPoint(x: r.midX, y: r.midY), rr = outer - line / 2
      let path = NSBezierPath(ovalIn: NSRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2))
      path.lineWidth = line
      NSColor.black.withAlphaComponent(ring).setStroke()
      path.stroke()
      if fill > 0 {
        let d = dot * fill
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: c.x - d, y: c.y - d, width: d * 2, height: d * 2)).fill()
      }
      return true
    }
    img.isTemplate = true
    img.accessibilityDescription = "clack"
    return img
  }
}

// listens to the bridge's Server-Sent Events and reconnects whenever the stream drops
final class Bridge: NSObject, URLSessionDataDelegate {
  var onOpen: () -> Void = {}
  var onEvent: ([String: Any]) -> Void = { _ in }
  var onDrop: () -> Void = {}
  private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: .main)
  private var task: URLSessionDataTask?
  private var buffer = Data()
  private var retry: TimeInterval = 2

  func connect() {
    task?.cancel()
    var req = URLRequest(url: base.appendingPathComponent("events"), cachePolicy: .reloadIgnoringLocalCacheData)
    // the bridge pings every 15 s, so a stream silent for longer than this is gone (a Mac waking from sleep, say)
    req.timeoutInterval = 40
    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    buffer.removeAll()
    task = session.dataTask(with: req)
    task?.resume()
  }

  func urlSession(_ s: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                  completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    let ok = (response as? HTTPURLResponse)?.statusCode == 200
    completionHandler(ok ? .allow : .cancel)
    if ok { onOpen() }
  }

  func urlSession(_ s: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    buffer.append(data)
    // an event ends at a blank line; its data: lines are joined, retry: sets the wait before reconnecting
    while let end = buffer.firstRange(of: Data("\n\n".utf8)) {
      let block = String(decoding: buffer[..<end.lowerBound], as: UTF8.self)
      buffer.removeSubrange(..<end.upperBound)
      var lines: [Substring] = []
      for line in block.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = line.hasSuffix("\r") ? line.dropLast() : line
        if line.hasPrefix("data:") { lines.append(line.dropFirst(5).drop { $0 == " " }) }
        else if line.hasPrefix("retry:"), let ms = Double(line.dropFirst(6).trimmingCharacters(in: .whitespaces)) { retry = ms / 1000 }
      }
      guard !lines.isEmpty, let json = try? JSONSerialization.jsonObject(with: Data(lines.joined(separator: "\n").utf8)),
            let e = json as? [String: Any] else { continue }
      onEvent(e)
    }
  }

  func urlSession(_ s: URLSession, task t: URLSessionTask, didCompleteWithError error: Error?) {
    guard t === task else { return }
    task = nil
    onDrop()
    DispatchQueue.main.asyncAfter(deadline: .now() + retry) { [weak self] in
      if self?.task == nil { self?.connect() }
    }
  }
}

// the popover stays open while you're in another app, so the first click back into clack plays as well as bringing
// it forward, rather than being spent on the bringing forward alone
final class Web: WKWebView {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// clack itself, kept loaded between openings so it opens at once and keeps its place
final class Page: NSViewController, WKNavigationDelegate, WKUIDelegate {
  let web: WKWebView
  private(set) var failed = false

  init() {
    let config = WKWebViewConfiguration()
    config.mediaTypesRequiringUserActionForPlayback = []
    web = Web(frame: NSRect(x: 0, y: 0, width: 420, height: 640), configuration: config)
    super.init(nibName: nil, bundle: nil)
    web.navigationDelegate = self
    web.uiDelegate = self
    if #available(macOS 13.3, *) { web.isInspectable = true }
  }
  required init?(coder: NSCoder) { fatalError() }

  override func loadView() { view = web }

  func load() { web.load(URLRequest(url: base, cachePolicy: .reloadIgnoringLocalCacheData)) }

  func webView(_ w: WKWebView, didCommit nav: WKNavigation!) {
    if w.url?.host == base.host { failed = false }
  }

  func webView(_ w: WKWebView, didFailProvisionalNavigation nav: WKNavigation!, withError error: Error) {
    // a load cut short by the next one isn't the bridge being down
    if (error as NSError).code == NSURLErrorCancelled { return }
    failed = true
    w.loadHTMLString(Page.offline, baseURL: nil)
  }

  // links off clack open in the browser, not in the popover
  func webView(_ w: WKWebView, decidePolicyFor action: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if let url = action.request.url, action.navigationType == .linkActivated, url.host != base.host {
      NSWorkspace.shared.open(url)
      return decisionHandler(.cancel)
    }
    decisionHandler(.allow)
  }

  func webView(_ w: WKWebView, createWebViewWith config: WKWebViewConfiguration, for action: WKNavigationAction,
               windowFeatures: WKWindowFeatures) -> WKWebView? {
    if let url = action.request.url { NSWorkspace.shared.open(url) }
    return nil
  }

  static let offline = """
  <!doctype html><meta charset="utf-8"><title>clack</title>
  <style>
    :root { color-scheme: light dark; --bg: #f4f5f7; --ink: #1b2a6b; --soft: #5a6890 }
    @media (prefers-color-scheme: dark) { :root { --bg: #14182a; --ink: #e6e9f5; --soft: #a3acc9 } }
    body { margin: 0; height: 100vh; display: grid; place-content: center; gap: 10px; padding: 0 40px; text-align: center;
           background: var(--bg); color: var(--ink); font: 15px/1.5 -apple-system, system-ui, sans-serif }
    p { margin: 0 } .soft { color: var(--soft); font-size: 13px } code { font: 12px ui-monospace, monospace }
  </style>
  <p>bridge offline</p>
  <p class="soft">clack opens here once its bridge answers on localhost:\(port).
  Installed, it starts with your Mac; to start it now, run<br><code>python3 clack-bridge.py</code></p>
  """
}

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let popover = NSPopover()
  private let page = Page()
  private let bridge = Bridge()
  private let menu = NSMenu()
  private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
  private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
  private var cameFrom: NSRunningApplication?

  private var phase = Phase.idle, reason = "", online = true, busy = 0
  private var waitAt = Date(), breathFrom: CFTimeInterval = 0, doneAt: CFTimeInterval = 0, ringAtDone: CGFloat = 1
  private var timer: Timer?
  private var shown: (CGFloat, CGFloat, Bool)?

  static let breath: CFTimeInterval = 2.8, fill: CFTimeInterval = 0.6

  func applicationDidFinishLaunching(_ n: Notification) {
    // one ring is enough: a second copy (opened again from Finder, say) leaves it to the first
    if let id = Bundle.main.bundleIdentifier,
       NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0 != .current }) {
      return NSApp.terminate(nil)
    }
    NSApp.setActivationPolicy(.accessory)

    if let b = item.button {
      b.target = self
      b.action = #selector(clicked)
      b.sendAction(on: [.leftMouseUp, .rightMouseUp])
      b.imagePosition = .imageOnly
      b.setAccessibilityLabel("clack")
    }

    popover.contentViewController = page
    popover.contentSize = NSSize(width: 420, height: 640)
    // closed only from the ring: clicks in other apps and switching apps leave it open, so clack stays beside your agent
    popover.behavior = .applicationDefined
    popover.animates = true

    statusLine.isEnabled = false
    menu.delegate = self
    menu.addItem(statusLine)
    menu.addItem(.separator())
    menu.addItem(withTitle: "Open in Browser", action: #selector(openInBrowser), keyEquivalent: "").target = self
    menu.addItem(withTitle: "Reload", action: #selector(reload), keyEquivalent: "").target = self
    menu.addItem(.separator())
    loginItem.target = self
    menu.addItem(loginItem)
    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit clack", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    bridge.onOpen = { [weak self] in self?.setOnline(true) }
    bridge.onDrop = { [weak self] in self?.setOnline(false) }
    bridge.onEvent = { [weak self] e in self?.handle(e) }
    bridge.connect()
    page.load()

    // the ring stays from login on unless you turn that off; and the copy you last opened is the one that opens
    if defaults.object(forKey: "openAtLogin") == nil || defaults.bool(forKey: "openAtLogin") { setOpenAtLogin(true) }

    let nc = NSWorkspace.shared.notificationCenter
    nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.bridge.connect() }
    // the app you were last in, which gets the keyboard back when you close clack from the ring
    cameFrom = NSWorkspace.shared.frontmostApplication.flatMap { $0 == .current ? nil : $0 }
    nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
      if let a = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, a != .current { self?.cameFrom = a }
    }
    // Esc closes it while clack has the keyboard (53 is Esc's key code); clack's own keys never use it
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
      guard let self, e.keyCode == 53, self.popover.isShown, e.window === self.page.view.window else { return e }
      self.close()
      return nil
    }
    render()
    if CommandLine.arguments.contains("--show") {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.open() }
    }
  }

  // MARK: the agent

  private func handle(_ e: [String: Any]) {
    let type = e["type"] as? String
    let at = (e["at"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
    // how many sessions are still working, and since when the longest of them has been (older bridges don't say)
    let since = (e["since"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
    if let n = e["working"] as? Int { busy = n }
    if type == "hello" {
      // what the bridge knows on (re)connecting; a done from before shows its dot without filling it in again
      switch e["phase"] as? String {
      case "wait": (phase, waitAt, breathFrom) = (.wait, since ?? at, CACurrentMediaTime())
      case "done": (phase, doneAt) = (.done, 0)
      default: phase = .idle
      }
    } else if type == "start" {
      // Claude waking itself up in one session leaves the dot of another one that finished
      if phase == .done, e["auto"] as? Bool == true { return render() }
      if phase != .wait { (waitAt, breathFrom) = (since ?? at, CACurrentMediaTime()) }
      phase = .wait
    } else if type == "done", phase == .wait {
      // like the page, a done with no wait behind it changes nothing
      ringAtDone = ringAlpha(CACurrentMediaTime())
      (phase, reason, doneAt) = (.done, e["reason"] as? String ?? "Stop", CACurrentMediaTime())
    } else if type == "tally", phase == .wait, busy == 0 {
      // the last working session closed or was stopped with Esc: you're at it already, so the wait just ends
      phase = .idle
    }
    render()
  }

  private func setOnline(_ on: Bool) {
    if on && !online && page.failed { page.load() }
    if !on { phase = .idle }
    online = on
    render()
  }

  private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

  private func ringAlpha(_ t: CFTimeInterval) -> CGFloat {
    guard phase == .wait else { return 1 }
    if reduceMotion { return 0.55 }
    // breathing out from full, slow enough to sit at the edge of your eye
    let p = (t - breathFrom).truncatingRemainder(dividingBy: App.breath)
    return 0.3 + 0.7 * CGFloat(0.5 + 0.5 * cos(2 * .pi * p / App.breath))
  }

  private func render() {
    let t = CACurrentMediaTime()
    var ring: CGFloat = 1, dot: CGFloat = 0, moving = false
    if online {
      switch phase {
      case .idle: break
      case .wait:
        ring = ringAlpha(t)
        moving = !reduceMotion
      case .done:
        let p = doneAt == 0 || reduceMotion ? 1 : min(1, CGFloat((t - doneAt) / App.fill))
        let ease = 1 - pow(1 - p, 3)
        dot = ease
        ring = ringAtDone + (1 - ringAtDone) * ease
        moving = p < 1
      }
    }
    if let s = shown, s.0 == ring, s.1 == dot, s.2 == online {} else {
      item.button?.image = Ring.image(ring: ring, dot: dot)
      item.button?.appearsDisabled = !online
      shown = (ring, dot, online)
    }
    let tip = "clack · " + status()
    if item.button?.toolTip != tip { item.button?.toolTip = tip }
    if moving, timer == nil {
      let tm = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.render() }
      RunLoop.main.add(tm, forMode: .common) // keeps breathing while the menu is open
      timer = tm
    } else if !moving {
      timer?.invalidate()
      timer = nil
    }
  }

  private func status() -> String {
    guard online else { return "bridge offline" }
    switch phase {
    case .idle: return "no agent running"
    case .wait:
      let s = max(0, Int(Date().timeIntervalSince(waitAt)))
      return (busy > 1 ? "\(busy) agents" : "agent") + String(format: " working · %d:%02d", s / 60, s % 60)
    case .done:
      let word = ["Notification": "agent needs you", "StopFailure": "agent stopped"][reason] ?? "agent done"
      return busy > 0 ? "\(word) · \(busy) still working" : word
    }
  }

  // MARK: the popover and the menu

  @objc private func clicked() {
    let e = NSApp.currentEvent
    if e?.type == .rightMouseUp || e?.modifierFlags.contains(.control) == true {
      close()
      item.menu = menu
      item.button?.performClick(nil)
      item.menu = nil
    } else if popover.isShown {
      close()
    } else {
      open()
    }
  }

  private func open() {
    guard let b = item.button else { return }
    if page.failed { page.load() }
    // the popover takes the keyboard, so clack's keys play; the app you were in gets it back when it closes
    NSApp.activate(ignoringOtherApps: true)
    popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
    popover.contentViewController?.view.window?.makeKey()
    popover.contentViewController?.view.window?.makeFirstResponder(page.web)
  }

  private func close() {
    guard popover.isShown else { return }
    popover.performClose(nil)
    // if clack still has the keyboard, the app you were last in gets it back
    if NSApp.isActive { cameFrom?.activate(options: []) }
  }

  func menuNeedsUpdate(_ m: NSMenu) {
    statusLine.title = status()
    loginItem.state = FileManager.default.fileExists(atPath: App.agentPlist.path) ? .on : .off
  }

  @objc private func openInBrowser() { NSWorkspace.shared.open(base) }
  @objc private func reload() { page.load(); bridge.connect() }

  // MARK: open at login, as a LaunchAgent like the bridge's own (ink.clack.bridge)

  static let agentLabel = "ink.clack.menubar"
  static let agentPlist = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")

  @objc private func toggleLogin() {
    setOpenAtLogin(!FileManager.default.fileExists(atPath: App.agentPlist.path))
  }

  private func setOpenAtLogin(_ on: Bool) {
    defaults.set(on, forKey: "openAtLogin")
    guard on else { try? FileManager.default.removeItem(at: App.agentPlist); return }
    // only written, not loaded: launchd reads it at the next login, and loading it now would start a second ring
    guard let exe = Bundle.main.executablePath else { return }
    let plist: [String: Any] = [
      "Label": App.agentLabel, "ProgramArguments": [exe], "RunAtLoad": true,
      "LimitLoadToSessionType": "Aqua", "ProcessType": "Interactive",
    ]
    try? FileManager.default.createDirectory(at: App.agentPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
      try? data.write(to: App.agentPlist)
    }
  }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.run()
