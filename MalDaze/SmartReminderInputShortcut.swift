import AppKit
import Foundation

/// 全局「添加提醒 / 智能输入」对话框快捷键；默认 ⌘⇧<（逗号键 + Shift，keyCode 43）。
struct SmartReminderInputShortcut: Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags
    var keyLabel: String

    static let defaultKeyCode: UInt16 = 43 // kVK_ANSI_Comma（与 Shift 组合为 <）

    static var defaultModifiers: NSEvent.ModifierFlags { [.command, .shift] }

    static var `default`: SmartReminderInputShortcut {
        SmartReminderInputShortcut(keyCode: defaultKeyCode, modifiers: defaultModifiers, keyLabel: "<")
    }

    static var defaultModifiersStorageInt: Int {
        Int(Self.default.modifiers.intersection(.deviceIndependentFlagsMask).rawValue)
    }

    var isEnabled: Bool {
        !modifiers.intersection(Self.requiredModifiers).isEmpty
    }

    static func load(from defaults: UserDefaults = .standard) -> SmartReminderInputShortcut {
        guard defaults.object(forKey: MalDazeDefaults.smartReminderInputShortcutKeyCode) != nil else {
            return .default
        }
        let kc = UInt16(clamping: defaults.integer(forKey: MalDazeDefaults.smartReminderInputShortcutKeyCode))
        let raw = UInt(clamping: max(0, defaults.integer(forKey: MalDazeDefaults.smartReminderInputShortcutModifiers)))
        let mods = NSEvent.ModifierFlags(rawValue: raw)
        let label = defaults.string(forKey: MalDazeDefaults.smartReminderInputShortcutKeyLabel) ?? ""
        return SmartReminderInputShortcut(keyCode: kc, modifiers: mods, keyLabel: label)
    }

    func save(to defaults: UserDefaults = .standard) {
        let masked = modifiers.intersection(.deviceIndependentFlagsMask)
        defaults.set(Int(keyCode), forKey: MalDazeDefaults.smartReminderInputShortcutKeyCode)
        defaults.set(Int(masked.rawValue), forKey: MalDazeDefaults.smartReminderInputShortcutModifiers)
        defaults.set(keyLabel, forKey: MalDazeDefaults.smartReminderInputShortcutKeyLabel)
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
