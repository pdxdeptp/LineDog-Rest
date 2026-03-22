import AppKit
import Foundation

/// 全局「桌宠菜单」快捷键：持久化 keyCode + 修饰键；默认 ⌘⇧.（ANSI Period，keyCode 47）。
struct DeskPetMenuShortcut: Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags
    /// 录制时的 `charactersIgnoringModifiers` 首字符，用于展示（与物理键位布局一致）。
    var keyLabel: String

    static let defaultKeyCode: UInt16 = 47

    static var defaultModifiers: NSEvent.ModifierFlags { [.command, .shift] }

    static var `default`: DeskPetMenuShortcut {
        DeskPetMenuShortcut(keyCode: defaultKeyCode, modifiers: defaultModifiers, keyLabel: ".")
    }

    /// 写入 UserDefaults 用的修饰键整型（与 `load` / `save` 一致）。
    static var defaultModifiersStorageInt: Int {
        Int(Self.default.modifiers.intersection(.deviceIndependentFlagsMask).rawValue)
    }

    static func load(from defaults: UserDefaults = .standard) -> DeskPetMenuShortcut {
        guard defaults.object(forKey: LineDogDefaults.deskPetMenuShortcutKeyCode) != nil else {
            return .default
        }
        let kc = UInt16(clamping: defaults.integer(forKey: LineDogDefaults.deskPetMenuShortcutKeyCode))
        let raw = UInt(clamping: max(0, defaults.integer(forKey: LineDogDefaults.deskPetMenuShortcutModifiers)))
        let mods = NSEvent.ModifierFlags(rawValue: raw)
        let label = defaults.string(forKey: LineDogDefaults.deskPetMenuShortcutKeyLabel) ?? ""
        return DeskPetMenuShortcut(keyCode: kc, modifiers: mods, keyLabel: label)
    }

    func save(to defaults: UserDefaults = .standard) {
        let masked = modifiers.intersection(.deviceIndependentFlagsMask)
        defaults.set(Int(keyCode), forKey: LineDogDefaults.deskPetMenuShortcutKeyCode)
        defaults.set(Int(masked.rawValue), forKey: LineDogDefaults.deskPetMenuShortcutModifiers)
        defaults.set(keyLabel, forKey: LineDogDefaults.deskPetMenuShortcutKeyLabel)
    }

    func matches(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let want = modifiers.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == keyCode && flags.rawValue == want.rawValue
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
