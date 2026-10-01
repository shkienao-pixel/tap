import AppKit
import WebKit
import Carbon
import ServiceManagement
import ShortcutCore

let generatedTag: Int64 = 0x5441504B

func sourceID() -> String {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(), let value = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return "" }
    return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
}
func switchInputSource() -> Bool {
    let target = sourceID() == "com.apple.inputmethod.SCIM.ITABC" ? "com.apple.keylayout.ABC" : "com.apple.inputmethod.SCIM.ITABC"
    let filter = [kTISPropertyInputSourceID as String: target] as CFDictionary
    guard let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource], let source = sources.first else { return false }
    return TISSelectInputSource(source) == noErr
}
func systemModifiersSwapped() -> Bool {
    let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/ByHost")
    let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
    for file in files where file.lastPathComponent.hasPrefix(".GlobalPreferences.") && file.pathExtension == "plist" {
        guard let data = try? Data(contentsOf: file), let prefs = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { continue }
        for (key, value) in prefs where key.hasPrefix("com.apple.keyboard.modifiermapping.") {
            guard let mappings = value as? [[String: NSNumber]] else { continue }
            if hasSystemModifierSwap(mappings.map { $0.mapValues { $0.uint64Value } }) { return true }
        }
    }
    return false
}

final class KeyboardMonitor {
    let engine = ShortcutEngine()
    var port: CFMachPort?
    var source: CFRunLoopSource?
    var onChange: (() -> Void)?
    var inputError = false
    var running: Bool { port.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }
    func start() {
        guard AXIsProcessTrusted() else { return }
        if let port { CGEvent.tapEnable(tap: port, enable: true); return }
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { proxy, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            return Unmanaged<KeyboardMonitor>.fromOpaque(context).takeUnretainedValue().handle(proxy, type, event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let port else { return }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: port, enable: true)
    }
    func stop() {
        releaseKeys()
        if let port { CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        port = nil; source = nil
    }
    func releaseKeys() { for release in engine.reset() { makeEvent(release)?.post(tap: .cghidEventTap) } }
    private func makeEvent(_ output: KeyOutput) -> CGEvent? {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: output.key, keyDown: output.down)
        event?.flags = CGEventFlags(rawValue: output.flags.rawValue)
        event?.setIntegerValueField(.eventSourceUserData, value: generatedTag)
        return event
    }
    private func editable(_ app: NSRunningApplication?) -> Bool {
        guard let app, !terminalBundles.contains(app.bundleIdentifier ?? "") else { return false }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.05)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXFocusedUIElementAttribute as CFString, &focused) == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.05)
        func attribute(_ name: String) -> CFTypeRef? { var result: CFTypeRef?; AXUIElementCopyAttributeValue(element, name as CFString, &result); return result }
        if attribute(kAXSubroleAttribute) as? String == kAXSecureTextFieldSubrole { return false }
        if let role = attribute(kAXRoleAttribute) as? String, [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role) { return true }
        return attribute("AXEditable") as? Bool == true
    }
    private func handle(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            releaseKeys()
            if let port, AXIsProcessTrusted(), !IsSecureEventInputEnabled() { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == generatedTag { return Unmanaged.passUnretained(event) }
        let kind: ShortcutCore.EventKind = type == .keyDown ? .down : type == .keyUp ? .up : type == .flagsChanged ? .flags : .mouse
        let input = KeyInput(UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode)), .init(rawValue: event.flags.rawValue), kind, time: ProcessInfo.processInfo.systemUptime, repeated: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
        let front = NSWorkspace.shared.frontmostApplication
        let secure = IsSecureEventInputEnabled()
        let context = ShortcutContext(bundle: front?.bundleIdentifier ?? "", editable: !secure && engine.needsTextContext(input) ? editable(front) : false, secure: secure)
        let result = engine.process(input, context: context)
        for output in result.outputs {
            if let replacement = makeEvent(output) {
                replacement.setIntegerValueField(.keyboardEventAutorepeat, value: event.getIntegerValueField(.keyboardEventAutorepeat))
                replacement.tapPostEvent(proxy)
            }
        }
        if result.switchInput {
            inputError = !switchInputSource()
            DispatchQueue.main.async { [weak self] in self?.onChange?() }
        }
        if result.consume { return nil }
        event.flags = CGEventFlags(rawValue: result.input.flags.rawValue)
        if kind != .mouse { event.setIntegerValueField(.keyboardEventKeycode, value: Int64(result.input.key)) }
        return Unmanaged.passUnretained(event)
    }
}

final class TapPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
func menuIcon() -> NSImage {
    let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
        NSColor.black.setStroke()
        let back = NSBezierPath(); back.move(to: .init(x: 5, y: 5.5)); back.line(to: .init(x: 4, y: 5.5)); back.curve(to: .init(x: 2, y: 7.5), controlPoint1: .init(x: 2, y: 5.5), controlPoint2: .init(x: 2, y: 5.5)); back.line(to: .init(x: 2, y: 14)); back.curve(to: .init(x: 4, y: 16), controlPoint1: .init(x: 2, y: 16), controlPoint2: .init(x: 2, y: 16)); back.line(to: .init(x: 12.5, y: 16)); back.curve(to: .init(x: 14.5, y: 14), controlPoint1: .init(x: 14.5, y: 16), controlPoint2: .init(x: 14.5, y: 16)); back.line(to: .init(x: 14.5, y: 13)); back.lineWidth = 1.3; back.lineCapStyle = .round; back.stroke()
        let front = NSBezierPath(roundedRect: .init(x: 5, y: 2, width: 13, height: 11), xRadius: 2.25, yRadius: 2.25); front.lineWidth = 1.3; front.stroke()
        let t = NSBezierPath(); t.move(to: .init(x: 9, y: 9.5)); t.line(to: .init(x: 14, y: 9.5)); t.move(to: .init(x: 11.5, y: 9.5)); t.line(to: .init(x: 11.5, y: 5)); t.lineWidth = 1.3; t.lineCapStyle = .round; t.stroke()
        return true
    }
    image.isTemplate = true; return image
}
final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    let monitor = KeyboardMonitor()
    let defaults = UserDefaults.standard
    var item: NSStatusItem!
    var panel: TapPanel!
    var web: WKWebView!
    var timer: Timer?
    var dragStart: (mouse: CGPoint, origin: CGPoint)?
    var loginError = ""
    var previousTrust = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        defaults.register(defaults: ["enabled": true, "shiftEnabled": true, "altEnabled": true, "controlEnabled": true, "alreadySwapped": systemModifiersSwapped()])
        loadPreferences()
        let mainMenu = NSMenu(); let appItem = NSMenuItem(); let appMenu = NSMenu(title: "Tap")
        appMenu.addItem(withTitle: "关于 Tap", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 Tap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; mainMenu.addItem(appItem); NSApp.mainMenu = mainMenu
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = menuIcon(); item.button?.toolTip = "Tap"
        item.button?.target = self; item.button?.action = #selector(menuClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        createPanel()
        monitor.onChange = { [weak self] in self?.refresh() }
        monitor.start(); previousTrust = AXIsProcessTrusted()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let trusted = AXIsProcessTrusted()
            if !trusted && self.previousTrust { self.monitor.stop() }
            if trusted && !IsSecureEventInputEnabled() { self.monitor.start() }
            self.previousTrust = trusted; self.refresh()
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "").count > 1 { NSApp.terminate(nil); return }
        if !CommandLine.arguments.contains("--background") { showPanel() }
    }
    func applicationWillTerminate(_ notification: Notification) { monitor.stop(); timer?.invalidate() }
    @objc func willSleep() { monitor.releaseKeys() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPanel(); return false }
    func loadPreferences() {
        monitor.engine.enabled = defaults.bool(forKey: "enabled")
        monitor.engine.shiftEnabled = defaults.bool(forKey: "shiftEnabled")
        monitor.engine.altEnabled = defaults.bool(forKey: "altEnabled")
        monitor.engine.controlEnabled = defaults.bool(forKey: "controlEnabled")
        monitor.engine.alreadySwapped = defaults.bool(forKey: "alreadySwapped")
        monitor.engine.options = (defaults.dictionary(forKey: "compatOptions") as? [String: Bool] ?? [:]).filter { key, _ in shortcutDefinitions.contains { $0.id == key } }
    }
    func createPanel() {
        panel = TapPanel(contentRect: .init(x: 0, y: 0, width: 520, height: 584), styleMask: [.borderless, .miniaturizable], backing: .buffered, defer: false)
        panel.title = "Tap"; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: .aqua)
        let container = NSView(frame: panel.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        let glass = NSVisualEffectView(frame: container.bounds.insetBy(dx: 8, dy: 8))
        glass.autoresizingMask = [.width, .height]; glass.blendingMode = .behindWindow
        glass.material = .popover; glass.state = .active; glass.wantsLayer = true
        glass.layer?.cornerRadius = 20; glass.layer?.masksToBounds = true
        container.addSubview(glass)
        let config = WKWebViewConfiguration(); config.userContentController.add(self, name: "tap")
        config.websiteDataStore = .nonPersistent()
        web = WKWebView(frame: container.bounds, configuration: config)
        web.autoresizingMask = [.width, .height]; web.setValue(false, forKey: "drawsBackground"); web.navigationDelegate = self
        container.addSubview(web); panel.contentView = container; panel.center()
        let url = Bundle.main.url(forResource: "panel", withExtension: "html") ?? Bundle.module.url(forResource: "panel", withExtension: "html", subdirectory: "Resources")!
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    func showPanel() { if panel.isMiniaturized { panel.deminiaturize(nil) }; panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); refresh() }
    @objc func menuClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp || NSEvent.modifierFlags.contains(.option) {
            let menu = NSMenu(); menu.addItem(withTitle: "打开 Tap", action: #selector(openPanel), keyEquivalent: "").target = self
            menu.addItem(withTitle: "重新连接键盘", action: #selector(reconnect), keyEquivalent: "").target = self
            menu.addItem(.separator()); menu.addItem(withTitle: "退出 Tap", action: #selector(quit), keyEquivalent: "").target = self
            if let button = item.button { menu.popUp(positioning: nil, at: .init(x: 0, y: button.bounds.height), in: button) }
        } else if panel.isVisible && !panel.isMiniaturized { panel.orderOut(nil) } else { showPanel() }
    }
    @objc func openPanel() { showPanel() }
    @objc func reconnect() { monitor.stop(); monitor.start(); refresh() }
    @objc func quit() { NSApp.terminate(nil) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { refresh() }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.request.url?.isFileURL == true ? .allow : .cancel)
    }
    func refresh() {
        guard panel.isVisible else { return }
        let definitions = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(shortcutDefinitions))) ?? []
        let e = monitor.engine
        let state: [String: Any] = ["enabled": e.enabled, "shiftEnabled": e.shiftEnabled, "altEnabled": e.altEnabled, "controlEnabled": e.controlEnabled, "alreadySwapped": e.alreadySwapped, "autoLaunch": SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval, "loginPending": SMAppService.mainApp.status == .requiresApproval, "accessibility": AXIsProcessTrusted(), "shiftListener": monitor.running, "altTabListener": monitor.running, "secureInput": IsSecureEventInputEnabled(), "inputSource": sourceID(), "inputError": monitor.inputError, "compatOptions": e.options, "compatDefinitions": definitions, "message": loginError]
        if let data = try? JSONSerialization.data(withJSONObject: state), let json = String(data: data, encoding: .utf8) { web.evaluateJavaScript("update(\(json))", completionHandler: nil) }
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let action = body["action"] as? String else { return }
        let value = body["value"]
        switch action {
        case "master": defaults.set(!monitor.engine.enabled, forKey: "enabled"); monitor.releaseKeys(); loadPreferences()
        case "shift", "alt", "control":
            if let value = value as? Bool { defaults.set(value, forKey: action == "shift" ? "shiftEnabled" : action == "alt" ? "altEnabled" : "controlEnabled"); monitor.releaseKeys(); loadPreferences() }
        case "modifierMode": if let value = value as? Bool { defaults.set(value, forKey: "alreadySwapped"); monitor.releaseKeys(); loadPreferences() }
        case "compat":
            if let value = value as? [String: Any], let id = value["id"] as? String, let on = value["enabled"] as? Bool, shortcutDefinitions.contains(where: { $0.id == id }) {
                var options = monitor.engine.options; options[id] = on; defaults.set(options, forKey: "compatOptions"); loadPreferences()
            }
        case "autostart":
            if let on = value as? Bool {
                do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginError = "" }
                catch { loginError = "登录启动设置失败，请将 Tap 移到应用程序后重试" }
            }
        case "permissions":
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        case "hide": panel.orderOut(nil)
        case "minimize": panel.miniaturize(nil)
        case "reload": reconnect()
        case "page":
            let screen = panel.screen ?? NSScreen.main!
            let h = min(value as? String == "more" ? 700.0 : 584.0, screen.visibleFrame.height - 32)
            let frame = panel.frame; panel.setFrame(.init(x: frame.minX, y: max(screen.visibleFrame.minY + 8, min(frame.midY - h / 2, screen.visibleFrame.maxY - h)), width: frame.width, height: h), display: true)
        case "dragStart": dragStart = (NSEvent.mouseLocation, panel.frame.origin)
        case "dragMove": if let start = dragStart { let current = NSEvent.mouseLocation; panel.setFrameOrigin(.init(x: start.origin.x + current.x - start.mouse.x, y: start.origin.y + current.y - start.mouse.y)) }
        case "dragEnd": dragStart = nil
        default: break
        }
        refresh()
    }
}

if CommandLine.arguments.contains("--self-check") {
    let html = Bundle.main.url(forResource: "panel", withExtension: "html")
    let icon = Bundle.main.url(forResource: "Tap", withExtension: "icns")
    guard html != nil, icon != nil else { fputs("Missing bundled resources\n", stderr); exit(1) }
    print("Tap standalone bundle OK; no Hammerspoon or Lua runtime required")
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate(); app.delegate = delegate; app.run()
}
