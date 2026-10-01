import Foundation

public struct KeyFlags: OptionSet, Equatable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    public static let caps = Self(rawValue: 1 << 16)
    public static let shift = Self(rawValue: 1 << 17)
    public static let control = Self(rawValue: 1 << 18)
    public static let option = Self(rawValue: 1 << 19)
    public static let command = Self(rawValue: 1 << 20)
    public static let function = Self(rawValue: 1 << 23)
    public func swappingControlCommand() -> Self {
        var result = self.subtracting([.control, .command])
        if contains(.control) { result.insert(.command) }
        if contains(.command) { result.insert(.control) }
        return result
    }
}
public enum EventKind { case down, up, flags, mouse }
public struct KeyInput {
    public var key: UInt16
    public var flags: KeyFlags
    public let kind: EventKind
    public let time: Double
    public let repeated: Bool
    public init(_ key: UInt16, _ flags: KeyFlags = [], _ kind: EventKind = .down, time: Double = 0, repeated: Bool = false) {
        self.key = key; self.flags = flags; self.kind = kind; self.time = time; self.repeated = repeated
    }
}
public struct KeyOutput: Equatable {
    public let key: UInt16
    public let flags: KeyFlags
    public let down: Bool
    public init(_ key: UInt16, _ flags: KeyFlags, down: Bool) { self.key = key; self.flags = flags; self.down = down }
}
public struct Decision {
    public var input: KeyInput
    public var consume = false
    public var outputs: [KeyOutput] = []
    public var switchInput = false
}
public struct ShortcutContext {
    public var bundle: String
    public var editable: Bool
    public var secure: Bool
    public init(bundle: String = "", editable: Bool = false, secure: Bool = false) {
        self.bundle = bundle; self.editable = editable; self.secure = secure
    }
}
public struct ShortcutDefinition: Codable {
    public let id: String, title: String, detail: String, category: String
}
public let shortcutDefinitions: [ShortcutDefinition] = [
    .init(id: "wordNavigation", title: "按词移动与选择", detail: "Ctrl + ← / → · Shift 选择", category: "文字编辑"),
    .init(id: "wordDelete", title: "按词删除", detail: "Ctrl + Backspace / Delete", category: "文字编辑"),
    .init(id: "lineNavigation", title: "行首与行尾", detail: "Home / End · Ctrl 跳文档首尾 · Shift 选择", category: "文字编辑"),
    .init(id: "redo", title: "重做", detail: "Ctrl + Y", category: "文字编辑"),
    .init(id: "browserTabs", title: "切换标签页", detail: "Ctrl + Tab · Shift 反向 · 仅浏览器", category: "应用与文件"),
    .init(id: "closeWindow", title: "关闭窗口", detail: "Alt + F4", category: "应用与文件"),
    .init(id: "finderRename", title: "文件重命名", detail: "F2 · 仅访达", category: "应用与文件"),
    .init(id: "screenshots", title: "截图到剪贴板", detail: "Win + Shift + S 选区 · Print Screen 全屏", category: "截图")
]
public let browserBundles: Set<String> = ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac", "org.mozilla.firefox", "com.brave.Browser", "company.thebrowser.Browser", "com.vivaldi.Vivaldi", "com.operasoftware.Opera"]
public let terminalBundles: Set<String> = ["com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable", "org.alacritty", "net.kovidgoyal.kitty"]

public final class ShortcutEngine {
    public var enabled = true
    public var shiftEnabled = true
    public var altEnabled = true
    public var controlEnabled = true
    public var alreadySwapped = false
    public var options: [String: Bool] = [:]
    public private(set) var nativeTabActive = false
    private var pendingShift: Double?
    private var previousShift = false
    private var held: [UInt16: (key: UInt16, flags: KeyFlags, repeatable: Bool)] = [:]
    private var swappingHeldModifiers = false
    public init() {}
    public func needsTextContext(_ input: KeyInput) -> Bool {
        guard input.kind == .down else { return false }
        return ([UInt16(123),124,51,117,115,119,16].contains(input.key) && options.contains { $0.value }) || (input.key == 120 && options["finderRename"] == true)
    }
    public func reset() -> [KeyOutput] {
        pendingShift = nil; previousShift = false
        var releases = held.values.map { KeyOutput($0.key, $0.flags, down: false) }
        held.removeAll()
        if nativeTabActive { releases.append(.init(55, [], down: false)) }
        nativeTabActive = false
        return releases
    }
    public func cancelShift() { pendingShift = nil; previousShift = false }
    public func process(_ raw: KeyInput, context: ShortcutContext = .init()) -> Decision {
        var d = Decision(input: raw)
        // Finish any replacement even if the app, preferences or master switch changed.
        if raw.kind == .down && !raw.repeated { held[raw.key] = nil }
        if let plan = held[raw.key], raw.kind == .up || raw.kind == .down {
            d.consume = true
            if raw.kind == .up || plan.repeatable {
                d.outputs = [.init(plan.key, plan.flags, down: raw.kind == .down)]
            }
            if raw.kind == .up { held[raw.key] = nil }
            return d
        }
        if context.secure {
            pendingShift = nil; previousShift = false
            if nativeTabActive { nativeTabActive = false; d.outputs = [.init(55, [], down: false)] }
            return d
        }
        let ctrlOrCmd = !raw.flags.intersection([.control, .command]).isEmpty
        let shouldSwap = enabled && controlEnabled && !alreadySwapped
        if shouldSwap && ctrlOrCmd { swappingHeldModifiers = true }
        // Drain a modifier key release after pausing instead of leaving Command held.
        if shouldSwap || swappingHeldModifiers {
            d.input.flags = raw.flags.swappingControlCommand()
            if raw.kind == .flags {
                switch raw.key { case 59: d.input.key = 55; case 62: d.input.key = 54; case 55: d.input.key = 59; case 54: d.input.key = 62; default: break }
            }
        }
        if !ctrlOrCmd { swappingHeldModifiers = false }
        let i = d.input, flags = i.flags
        if nativeTabActive && (!enabled || !altEnabled) {
            nativeTabActive = false; d.outputs.append(.init(55, [], down: false))
        }
        guard enabled else { cancelShift(); return d }
        if i.kind == .mouse { cancelShift(); return d }
        let other = !flags.intersection([.control, .command, .option, .function]).isEmpty
        if shiftEnabled && i.kind == .flags {
            let shift = flags.contains(.shift)
            if (raw.key == 56 || raw.key == 60) && shift && !previousShift && !other { pendingShift = i.time }
            else if (raw.key == 56 || raw.key == 60) && !shift && previousShift {
                if let started = pendingShift, !other, i.time - started <= 0.5 { d.switchInput = true }
                pendingShift = nil
            } else { pendingShift = nil }
            previousShift = shift
        } else if i.kind != .flags { pendingShift = nil }
        let startTab = altEnabled && i.kind == .down && i.key == 48 && flags.contains(.option) && flags.intersection([.command, .control, .function]).isEmpty
        if nativeTabActive || startTab {
            pendingShift = nil
            if i.kind == .flags && !flags.contains(.option) {
                nativeTabActive = false; d.input.key = 55
                d.input.flags = flags.subtracting([.option, .command]); return d
            }
            d.input.flags = flags.subtracting(.option).union(.command)
            if startTab && !nativeTabActive {
                nativeTabActive = true; d.consume = true
                d.outputs.append(.init(55, d.input.flags, down: true))
                d.outputs.append(.init(i.key, d.input.flags, down: true))
            }
            return d
        }
        guard i.kind == .down, let plan = resolve(i, context: context) else { return d }
        pendingShift = nil; held[raw.key] = plan; d.consume = true
        d.outputs.append(.init(plan.key, plan.flags, down: true))
        return d
    }
    private func resolve(_ i: KeyInput, context c: ShortcutContext) -> (key: UInt16, flags: KeyFlags, repeatable: Bool)? {
        let f = i.flags, shift: KeyFlags = f.contains(.shift) ? .shift : []
        let plain = f.intersection([.command, .control, .option]).isEmpty
        let command = f.contains(.command) && f.intersection([.control, .option]).isEmpty
        func on(_ id: String) -> Bool { options[id] == true }
        if on("browserTabs"), browserBundles.contains(c.bundle), i.key == 48, command, !f.contains(.function) { return (48, shift.union(.control), true) }
        if on("closeWindow"), i.key == 118, f.contains(.option), f.intersection([.command, .control, .shift]).isEmpty { return (13, .command, false) }
        if on("finderRename"), c.bundle == "com.apple.finder", !c.editable, i.key == 120, plain, shift.isEmpty { return (36, [], false) }
        if on("screenshots") {
            if i.key == 1, f.contains([.control, .shift]), f.intersection([.command, .option, .function]).isEmpty { return (21, [.command, .control, .shift], false) }
            if i.key == 105, plain, shift.isEmpty { return (20, [.command, .control, .shift], false) }
        }
        guard c.editable, !terminalBundles.contains(c.bundle), c.bundle != "com.apple.finder" else { return nil }
        if on("lineNavigation"), i.key == 115 || i.key == 119, plain || command {
            return (command ? (i.key == 115 ? 126 : 125) : (i.key == 115 ? 123 : 124), shift.union(.command), true)
        }
        guard command else { return nil }
        if on("wordNavigation"), i.key == 123 || i.key == 124 { return (i.key, shift.union(.option), true) }
        if on("wordDelete"), i.key == 51 || i.key == 117, shift.isEmpty { return (i.key, .option, true) }
        if on("redo"), i.key == 16, shift.isEmpty, !f.contains(.function) { return (6, [.command, .shift], false) }
        return nil
    }
}

// IOHID encodes the usage page in the upper 32 bits, not the upper 16 bits.
public func hasSystemModifierSwap(_ mappings: [[String: UInt64]]) -> Bool {
    for (control, command) in [(UInt64(0x7000000e0), UInt64(0x7000000e3)), (UInt64(0x7000000e4), UInt64(0x7000000e7))] {
        let forward = mappings.contains { $0["HIDKeyboardModifierMappingSrc"] == control && $0["HIDKeyboardModifierMappingDst"] == command }
        let backward = mappings.contains { $0["HIDKeyboardModifierMappingSrc"] == command && $0["HIDKeyboardModifierMappingDst"] == control }
        if forward && backward { return true }
    }
    return false
}
