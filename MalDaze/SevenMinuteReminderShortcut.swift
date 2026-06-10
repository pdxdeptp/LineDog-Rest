import AppKit
import Foundation

/// 全局「独立倒计时提醒」开/关切换；默认 ⌘⇧M（ANSI M，keyCode 46）。
struct SevenMinuteReminderShortcut: Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags
    var keyLabel: String

    static let defaultKeyCode: UInt16 = 46 // kVK_ANSI_M

    static var defaultModifiers: NSEvent.ModifierFlags { [.command, .shift] }

    static var `default`: SevenMinuteReminderShortcut {
        SevenMinuteReminderShortcut(keyCode: defaultKeyCode, modifiers: defaultModifiers, keyLabel: "M")
    }

    static var defaultModifiersStorageInt: Int {
        Int(Self.default.modifiers.intersection(.deviceIndependentFlagsMask).rawValue)
    }

    var isEnabled: Bool {
        !modifiers.intersection(Self.requiredModifiers).isEmpty
    }

    static func load(from defaults: UserDefaults = .standard) -> SevenMinuteReminderShortcut {
        guard defaults.object(forKey: MalDazeDefaults.sevenMinuteReminderShortcutKeyCode) != nil else {
            return .default
        }
        let kc = UInt16(clamping: defaults.integer(forKey: MalDazeDefaults.sevenMinuteReminderShortcutKeyCode))
        let raw = UInt(clamping: max(0, defaults.integer(forKey: MalDazeDefaults.sevenMinuteReminderShortcutModifiers)))
        let mods = NSEvent.ModifierFlags(rawValue: raw)
        let label = defaults.string(forKey: MalDazeDefaults.sevenMinuteReminderShortcutKeyLabel) ?? ""
        return SevenMinuteReminderShortcut(keyCode: kc, modifiers: mods, keyLabel: label)
    }

    func save(to defaults: UserDefaults = .standard) {
        let masked = modifiers.intersection(.deviceIndependentFlagsMask)
        defaults.set(Int(keyCode), forKey: MalDazeDefaults.sevenMinuteReminderShortcutKeyCode)
        defaults.set(Int(masked.rawValue), forKey: MalDazeDefaults.sevenMinuteReminderShortcutModifiers)
        defaults.set(keyLabel, forKey: MalDazeDefaults.sevenMinuteReminderShortcutKeyLabel)
    }

    var displayString: String {
        guard isEnabled else { return "已关闭" }
        var s = ""
        let m = modifiers.intersection(.deviceIndependentFlagsMask)
        if m.contains(.control) { s += "⌃" }
        if m.contains(.option) { s += "⌥" }
        if m.contains(.shift) { s += "⇧" }
        if m.contains(.command) { s += "⌘" }
        if keyLabel.isEmpty {
            s += Self.fallbackSymbol(for: keyCode)
        } else {
            s += keyLabel
        }
        return s
    }

    private static var requiredModifiers: NSEvent.ModifierFlags {
        [.command, .option, .control, .shift]
    }

    private static func fallbackSymbol(for keyCode: UInt16) -> String {
        switch keyCode {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123...126: return "方向键"
        default: return "键码 \(keyCode)"
        }
    }
}
