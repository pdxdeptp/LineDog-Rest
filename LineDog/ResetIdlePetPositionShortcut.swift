import AppKit
import Foundation

/// 全局「桌宠回到菜单栏屏可见区右下角」；默认 ⌘⇧R（ANSI R，keyCode 15）。
struct ResetIdlePetPositionShortcut: Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags
    var keyLabel: String

    static let defaultKeyCode: UInt16 = 15 // kVK_ANSI_R

    static var defaultModifiers: NSEvent.ModifierFlags { [.command, .shift] }

    static var `default`: ResetIdlePetPositionShortcut {
        ResetIdlePetPositionShortcut(keyCode: defaultKeyCode, modifiers: defaultModifiers, keyLabel: "R")
    }

    static var defaultModifiersStorageInt: Int {
        Int(Self.default.modifiers.intersection(.deviceIndependentFlagsMask).rawValue)
    }

    static func load(from defaults: UserDefaults = .standard) -> ResetIdlePetPositionShortcut {
        guard defaults.object(forKey: LineDogDefaults.resetIdlePetShortcutKeyCode) != nil else {
            return .default
        }
        let kc = UInt16(clamping: defaults.integer(forKey: LineDogDefaults.resetIdlePetShortcutKeyCode))
        let raw = UInt(clamping: max(0, defaults.integer(forKey: LineDogDefaults.resetIdlePetShortcutModifiers)))
        let mods = NSEvent.ModifierFlags(rawValue: raw)
        let label = defaults.string(forKey: LineDogDefaults.resetIdlePetShortcutKeyLabel) ?? ""
        return ResetIdlePetPositionShortcut(keyCode: kc, modifiers: mods, keyLabel: label)
    }

    func save(to defaults: UserDefaults = .standard) {
        let masked = modifiers.intersection(.deviceIndependentFlagsMask)
        defaults.set(Int(keyCode), forKey: LineDogDefaults.resetIdlePetShortcutKeyCode)
        defaults.set(Int(masked.rawValue), forKey: LineDogDefaults.resetIdlePetShortcutModifiers)
        defaults.set(keyLabel, forKey: LineDogDefaults.resetIdlePetShortcutKeyLabel)
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
