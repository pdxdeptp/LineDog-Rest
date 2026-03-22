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

    static func load(from defaults: UserDefaults = .standard) -> SevenMinuteReminderShortcut {
        guard defaults.object(forKey: LineDogDefaults.sevenMinuteReminderShortcutKeyCode) != nil else {
            return .default
        }
        let kc = UInt16(clamping: defaults.integer(forKey: LineDogDefaults.sevenMinuteReminderShortcutKeyCode))
        let raw = UInt(clamping: max(0, defaults.integer(forKey: LineDogDefaults.sevenMinuteReminderShortcutModifiers)))
        let mods = NSEvent.ModifierFlags(rawValue: raw)
        let label = defaults.string(forKey: LineDogDefaults.sevenMinuteReminderShortcutKeyLabel) ?? ""
        return SevenMinuteReminderShortcut(keyCode: kc, modifiers: mods, keyLabel: label)
    }

    func save(to defaults: UserDefaults = .standard) {
        let masked = modifiers.intersection(.deviceIndependentFlagsMask)
        defaults.set(Int(keyCode), forKey: LineDogDefaults.sevenMinuteReminderShortcutKeyCode)
        defaults.set(Int(masked.rawValue), forKey: LineDogDefaults.sevenMinuteReminderShortcutModifiers)
        defaults.set(keyLabel, forKey: LineDogDefaults.sevenMinuteReminderShortcutKeyLabel)
    }

    var displayString: String {
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
