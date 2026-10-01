import XCTest
@testable import ShortcutCore

final class ShortcutEngineTests: XCTestCase {
    let text = ShortcutContext(bundle: "com.google.Chrome", editable: true)
    func testDetectsRealIOHIDMappingValues() {
        XCTAssertTrue(hasSystemModifierSwap([
            ["HIDKeyboardModifierMappingSrc": 30064771296, "HIDKeyboardModifierMappingDst": 30064771299],
            ["HIDKeyboardModifierMappingSrc": 30064771299, "HIDKeyboardModifierMappingDst": 30064771296]
        ]))
        XCTAssertFalse(hasSystemModifierSwap([]))
        XCTAssertFalse(hasSystemModifierSwap([["HIDKeyboardModifierMappingSrc": 30064771296, "HIDKeyboardModifierMappingDst": 30064771299]]))
    }
    func testShiftReleaseAndCancellation() {
        let e = ShortcutEngine()
        XCTAssertFalse(e.process(.init(56, .shift, .flags, time: 1)).switchInput)
        XCTAssertTrue(e.process(.init(56, [], .flags, time: 1.2)).switchInput)
        _ = e.process(.init(56, .shift, .flags, time: 2))
        XCTAssertFalse(e.process(.init(56, [], .flags, time: 2.6)).switchInput)
        _ = e.process(.init(56, .shift, .flags, time: 3))
        _ = e.process(.init(0, .shift, .down, time: 3.1))
        XCTAssertFalse(e.process(.init(56, [], .flags, time: 3.2)).switchInput)
        _ = e.process(.init(56, [.shift, .option], .flags, time: 4))
        XCTAssertFalse(e.process(.init(56, .option, .flags, time: 4.2)).switchInput)
        _ = e.process(.init(56, .shift, .flags, time: 5))
        _ = e.process(.init(0, .shift, .mouse, time: 5.1))
        XCTAssertFalse(e.process(.init(56, [], .flags, time: 5.2)).switchInput)
        e.shiftEnabled = false
        _ = e.process(.init(56, .shift, .flags, time: 6))
        XCTAssertFalse(e.process(.init(56, [], .flags, time: 6.2)).switchInput)
    }
    func testControlMappingAndSystemSwapMode() {
        let e = ShortcutEngine()
        for key: UInt16 in [0,6,7,8,9,1,3] {
            XCTAssertEqual(e.process(.init(key, .control)).input.flags, .command)
        }
        XCTAssertEqual(e.process(.init(59, .control, .flags)).input.key, 55)
        XCTAssertEqual(e.process(.init(55, .command, .flags)).input.key, 59)
        XCTAssertEqual(e.process(.init(0, [.control,.shift,.caps], .mouse)).input.flags, [.command,.shift,.caps])
        _ = e.process(.init(59, [], .flags))
        e.alreadySwapped = true
        XCTAssertEqual(e.process(.init(8, .command)).input.flags, .command)
        XCTAssertEqual(e.process(.init(8, .control)).input.flags, .control)
        e.alreadySwapped = false; e.controlEnabled = false
        XCTAssertEqual(e.process(.init(8, .control)).input.flags, .control)
    }
    func testPausingDrainsPhysicalModifierRelease() {
        let e = ShortcutEngine()
        _ = e.process(.init(59, .control, .flags))
        e.enabled = false
        XCTAssertEqual(e.process(.init(59, [], .flags)).input.key, 55)
        XCTAssertEqual(e.process(.init(8, .control)).input.flags, .control)
    }
    func testNativeTabSession() {
        let e = ShortcutEngine()
        let start = e.process(.init(48, .option))
        XCTAssertTrue(start.consume); XCTAssertTrue(e.nativeTabActive)
        XCTAssertEqual(start.outputs, [.init(55, .command, down: true), .init(48, .command, down: true)])
        XCTAssertEqual(e.process(.init(48, [.option,.shift], .up)).input.flags, [.command,.shift])
        XCTAssertEqual(e.process(.init(123, .option)).input.flags, .command)
        let end = e.process(.init(58, [], .flags))
        XCTAssertEqual(end.input.key, 55); XCTAssertEqual(end.input.flags, [])
        XCTAssertFalse(e.nativeTabActive)
    }
    func testNativeTabDoesNotHijackOtherCombinations() {
        let e = ShortcutEngine()
        for flags: KeyFlags in [[.option,.control],[.option,.command],[.option,.function]] {
            XCTAssertFalse(e.process(.init(48, flags)).consume)
            XCTAssertFalse(e.nativeTabActive)
        }
        e.altEnabled = false; XCTAssertFalse(e.process(.init(48, .option)).consume)
    }
    func testPauseAndResetReleaseNativeCommand() {
        let e = ShortcutEngine(); _ = e.process(.init(48, .option))
        e.enabled = false
        XCTAssertEqual(e.process(.init(0)).outputs, [.init(55, [], down: false)])
        XCTAssertFalse(e.nativeTabActive)
        e.enabled = true; _ = e.process(.init(48, .option))
        XCTAssertEqual(e.reset(), [.init(55, [], down: false)])
    }
    func testOptionsStartOffAndPassThrough() {
        let e = ShortcutEngine(); e.alreadySwapped = true; e.altEnabled = false
        for key: UInt16 in [123,124,51,117,115,119,16,48,118,120,105,1] {
            for flags: KeyFlags in [[],.command,.option,[.control,.shift]] {
                XCTAssertFalse(e.process(.init(key, flags), context: text).consume)
            }
        }
        XCTAssertTrue(shortcutDefinitions.allSatisfy { e.options[$0.id] != true })
    }
    func testOptionalMappingsAndSelection() {
        let e = ShortcutEngine(); e.alreadySwapped = true
        e.options = Dictionary(uniqueKeysWithValues: shortcutDefinitions.map { ($0.id, true) })
        let cases: [(UInt16,KeyFlags,UInt16,KeyFlags)] = [
            (123,.command,123,.option),(124,[.command,.shift],124,[.option,.shift]),
            (51,.command,51,.option),(117,.command,117,.option),
            (115,[],123,.command),(119,.shift,124,[.command,.shift]),
            (115,[.command,.shift],126,[.command,.shift]),(119,.command,125,.command),
            (16,.command,6,[.command,.shift]),(48,.command,48,.control),
            (48,[.command,.shift],48,[.control,.shift]),(118,.option,13,.command),
            (1,[.control,.shift],21,[.command,.control,.shift]),(105,[],20,[.command,.control,.shift])
        ]
        for (key,flags,target,output) in cases {
            XCTAssertEqual(e.process(.init(key,flags),context:text).outputs,[.init(target,output,down:true)])
            XCTAssertEqual(e.process(.init(key,[],.up),context:text).outputs,[.init(target,output,down:false)])
        }
        XCTAssertEqual(e.process(.init(120),context:.init(bundle:"com.apple.finder")).outputs,[.init(36,[],down:true)])
        _ = e.process(.init(120,[],.up))
        XCTAssertFalse(e.process(.init(120),context:.init(bundle:"com.apple.finder",editable:true)).consume)
    }
    func testOptionalScopeAndSecurity() {
        let e = ShortcutEngine(); e.alreadySwapped = true
        e.options = Dictionary(uniqueKeysWithValues: shortcutDefinitions.map { ($0.id,true) })
        for terminal in terminalBundles {
            XCTAssertFalse(e.process(.init(123,.command),context:.init(bundle:terminal,editable:true)).consume)
        }
        XCTAssertFalse(e.process(.init(123,.command),context:.init(bundle:"com.google.Chrome",editable:false)).consume)
        XCTAssertFalse(e.process(.init(48,.command),context:.init(bundle:"com.apple.finder")).consume)
        XCTAssertFalse(e.process(.init(123,[.command,.option]),context:text).consume)
        XCTAssertFalse(e.process(.init(48,.command),context:.init(bundle:"com.google.Chrome",secure:true)).consume)
        XCTAssertFalse(e.process(.init(8,.control),context:.init(secure:true)).input.flags.contains(.command))
    }
    func testHeldReplacementSurvivesOptionAndApplicationChange() {
        let e = ShortcutEngine(); e.alreadySwapped = true; e.options["browserTabs"] = true
        XCTAssertEqual(e.process(.init(48,.command),context:text).outputs,[.init(48,.control,down:true)])
        e.options["browserTabs"] = false; e.enabled = false
        XCTAssertEqual(e.process(.init(48,[],.up),context:.init(bundle:"com.apple.finder")).outputs,[.init(48,.control,down:false)])
        XCTAssertFalse(e.process(.init(48,.command),context:text).consume)
    }
    func testLostReleaseRespectsChangedPreference() {
        let e = ShortcutEngine(); e.alreadySwapped = true; e.options["wordNavigation"] = true
        _ = e.process(.init(123,.command),context:text)
        e.options["wordNavigation"] = false
        XCTAssertFalse(e.process(.init(123,.command),context:text).consume)
    }
    func testNonrepeatableShortcutsDoNotCloseMultipleWindows() {
        let e = ShortcutEngine(); e.options["closeWindow"] = true
        XCTAssertTrue(e.process(.init(118,.option)).consume)
        let repeated = e.process(.init(118,.option,repeated:true))
        XCTAssertTrue(repeated.consume); XCTAssertTrue(repeated.outputs.isEmpty)
        XCTAssertEqual(e.process(.init(118,[],.up)).outputs,[.init(13,.command,down:false)])
    }
}
