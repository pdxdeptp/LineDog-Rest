import AppKit
import XCTest
@testable import MalDaze

final class GlobalShortcutModelTests: XCTestCase {
    private let shortcutHarnesses: [AnyShortcutHarness] = [
        AnyShortcutHarness(ShortcutHarness(
            name: "smart input",
            defaultShortcut: SmartReminderInputShortcut.default,
            defaultKeyCode: SmartReminderInputShortcut.defaultKeyCode,
            defaultModifiersStorageInt: SmartReminderInputShortcut.defaultModifiersStorageInt,
            keyCodeKey: MalDazeDefaults.smartReminderInputShortcutKeyCode,
            modifiersKey: MalDazeDefaults.smartReminderInputShortcutModifiers,
            keyLabelKey: MalDazeDefaults.smartReminderInputShortcutKeyLabel,
            make: SmartReminderInputShortcut.init,
            keyCode: \.keyCode,
            modifiers: \.modifiers,
            keyLabel: \.keyLabel,
            isEnabled: \.isEnabled,
            displayString: \.displayString,
            load: SmartReminderInputShortcut.load,
            save: { $0.save(to: $1) }
        )),
        AnyShortcutHarness(ShortcutHarness(
            name: "desk menu",
            defaultShortcut: DeskPetMenuShortcut.default,
            defaultKeyCode: DeskPetMenuShortcut.defaultKeyCode,
            defaultModifiersStorageInt: DeskPetMenuShortcut.defaultModifiersStorageInt,
            keyCodeKey: MalDazeDefaults.deskPetMenuShortcutKeyCode,
            modifiersKey: MalDazeDefaults.deskPetMenuShortcutModifiers,
            keyLabelKey: MalDazeDefaults.deskPetMenuShortcutKeyLabel,
            make: DeskPetMenuShortcut.init,
            keyCode: \.keyCode,
            modifiers: \.modifiers,
            keyLabel: \.keyLabel,
            isEnabled: \.isEnabled,
            displayString: \.displayString,
            load: DeskPetMenuShortcut.load,
            save: { $0.save(to: $1) }
        )),
        AnyShortcutHarness(ShortcutHarness(
            name: "seven-minute reminder",
            defaultShortcut: SevenMinuteReminderShortcut.default,
            defaultKeyCode: SevenMinuteReminderShortcut.defaultKeyCode,
            defaultModifiersStorageInt: SevenMinuteReminderShortcut.defaultModifiersStorageInt,
            keyCodeKey: MalDazeDefaults.sevenMinuteReminderShortcutKeyCode,
            modifiersKey: MalDazeDefaults.sevenMinuteReminderShortcutModifiers,
            keyLabelKey: MalDazeDefaults.sevenMinuteReminderShortcutKeyLabel,
            make: SevenMinuteReminderShortcut.init,
            keyCode: \.keyCode,
            modifiers: \.modifiers,
            keyLabel: \.keyLabel,
            isEnabled: \.isEnabled,
            displayString: \.displayString,
            load: SevenMinuteReminderShortcut.load,
            save: { $0.save(to: $1) }
        )),
        AnyShortcutHarness(ShortcutHarness(
            name: "pet reset",
            defaultShortcut: ResetIdlePetPositionShortcut.default,
            defaultKeyCode: ResetIdlePetPositionShortcut.defaultKeyCode,
            defaultModifiersStorageInt: ResetIdlePetPositionShortcut.defaultModifiersStorageInt,
            keyCodeKey: MalDazeDefaults.resetIdlePetShortcutKeyCode,
            modifiersKey: MalDazeDefaults.resetIdlePetShortcutModifiers,
            keyLabelKey: MalDazeDefaults.resetIdlePetShortcutKeyLabel,
            make: ResetIdlePetPositionShortcut.init,
            keyCode: \.keyCode,
            modifiers: \.modifiers,
            keyLabel: \.keyLabel,
            isEnabled: \.isEnabled,
            displayString: \.displayString,
            load: ResetIdlePetPositionShortcut.load,
            save: { $0.save(to: $1) }
        ))
    ]

    func testMissingStoredKeyCodeLoadsExistingDefaultForEveryShortcut() {
        for harness in shortcutHarnesses {
            let defaults = makeDefaults()

            let loaded = harness.load(defaults)

            XCTAssertEqual(harness.keyCode(loaded), harness.defaultKeyCode, harness.name)
            XCTAssertEqual(harness.modifiers(loaded), harness.modifiers(harness.defaultShortcut), harness.name)
            XCTAssertEqual(harness.keyLabel(loaded), harness.keyLabel(harness.defaultShortcut), harness.name)
            XCTAssertEqual(harness.defaultModifiersStorageInt, Int(harness.modifiers(harness.defaultShortcut).intersection(.deviceIndependentFlagsMask).rawValue), harness.name)
        }
    }

    func testPartialStoredShortcutWithoutKeyCodeLoadsExistingDefaultForEveryShortcut() {
        for harness in shortcutHarnesses {
            let defaults = makeDefaults()
            defaults.set(Int(NSEvent.ModifierFlags([.control, .option]).rawValue), forKey: harness.modifiersKey)
            defaults.set("X", forKey: harness.keyLabelKey)

            let loaded = harness.load(defaults)

            XCTAssertEqual(harness.keyCode(loaded), harness.defaultKeyCode, harness.name)
            XCTAssertEqual(harness.modifiers(loaded), harness.modifiers(harness.defaultShortcut), harness.name)
            XCTAssertEqual(harness.keyLabel(loaded), harness.keyLabel(harness.defaultShortcut), harness.name)
        }
    }

    func testShortcutSaveLoadRoundTripUsesExistingDefaultsKeysAndMasksModifiers() {
        let unmaskedRaw = NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.option.rawValue | 0x1

        for harness in shortcutHarnesses {
            let defaults = makeDefaults()
            let shortcut = harness.make(36, NSEvent.ModifierFlags(rawValue: unmaskedRaw), "")

            harness.save(shortcut, defaults)
            let loaded = harness.load(defaults)

            XCTAssertEqual(defaults.integer(forKey: harness.keyCodeKey), 36, harness.name)
            XCTAssertEqual(defaults.integer(forKey: harness.modifiersKey), Int(NSEvent.ModifierFlags([.command, .option]).rawValue), harness.name)
            XCTAssertEqual(defaults.string(forKey: harness.keyLabelKey), "", harness.name)
            XCTAssertTrue(harness.equals(loaded, harness.make(36, [.command, .option], "")), harness.name)
        }
    }

    func testDisplayAndEnabledSemanticsAreSharedForEveryShortcut() {
        for harness in shortcutHarnesses {
            let disabled = harness.make(0, [], "")
            let fallback = harness.make(36, [.command], "")

            XCTAssertFalse(harness.isEnabled(disabled), harness.name)
            XCTAssertEqual(harness.displayString(disabled), "已关闭", harness.name)
            XCTAssertTrue(harness.isEnabled(fallback), harness.name)
            XCTAssertEqual(harness.displayString(fallback), "⌘↩", harness.name)
        }
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "GlobalShortcutModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private struct AnyShortcutHarness {
    let name: String
    let defaultShortcut: Any
    let defaultKeyCode: UInt16
    let defaultModifiersStorageInt: Int
    let keyCodeKey: String
    let modifiersKey: String
    let keyLabelKey: String
    let make: (UInt16, NSEvent.ModifierFlags, String) -> Any
    let keyCode: (Any) -> UInt16
    let modifiers: (Any) -> NSEvent.ModifierFlags
    let keyLabel: (Any) -> String
    let isEnabled: (Any) -> Bool
    let displayString: (Any) -> String
    let load: (UserDefaults) -> Any
    let save: (Any, UserDefaults) -> Void
    let equals: (Any, Any) -> Bool

    init<Shortcut: Equatable>(_ harness: ShortcutHarness<Shortcut>) {
        name = harness.name
        defaultShortcut = harness.defaultShortcut
        defaultKeyCode = harness.defaultKeyCode
        defaultModifiersStorageInt = harness.defaultModifiersStorageInt
        keyCodeKey = harness.keyCodeKey
        modifiersKey = harness.modifiersKey
        keyLabelKey = harness.keyLabelKey
        make = harness.make
        keyCode = { harness.keyCode($0 as! Shortcut) }
        modifiers = { harness.modifiers($0 as! Shortcut) }
        keyLabel = { harness.keyLabel($0 as! Shortcut) }
        isEnabled = { harness.isEnabled($0 as! Shortcut) }
        displayString = { harness.displayString($0 as! Shortcut) }
        load = harness.load
        save = { harness.save($0 as! Shortcut, $1) }
        equals = { ($0 as! Shortcut) == ($1 as! Shortcut) }
    }
}

private struct ShortcutHarness<Shortcut: Equatable> {
    let name: String
    let defaultShortcut: Shortcut
    let defaultKeyCode: UInt16
    let defaultModifiersStorageInt: Int
    let keyCodeKey: String
    let modifiersKey: String
    let keyLabelKey: String
    let make: (UInt16, NSEvent.ModifierFlags, String) -> Shortcut
    let keyCode: (Shortcut) -> UInt16
    let modifiers: (Shortcut) -> NSEvent.ModifierFlags
    let keyLabel: (Shortcut) -> String
    let isEnabled: (Shortcut) -> Bool
    let displayString: (Shortcut) -> String
    let load: (UserDefaults) -> Shortcut
    let save: (Shortcut, UserDefaults) -> Void
}
