import AppKit
import Foundation

struct GlobalShortcutDescriptor: Equatable {
    let keyCodeKey: String
    let modifiersKey: String
    let keyLabelKey: String
    let defaultValue: GlobalShortcut

    var defaultModifiersStorageInt: Int {
        Int(defaultValue.modifiers.intersection(.deviceIndependentFlagsMask).rawValue)
    }
}

struct GlobalShortcut: Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags
    var keyLabel: String

    var isEnabled: Bool {
        !modifiers.intersection(Self.requiredModifiers).isEmpty
    }

    var displayString: String {
        guard isEnabled else { return "已关闭" }

        var display = ""
        let maskedModifiers = modifiers.intersection(.deviceIndependentFlagsMask)
        if maskedModifiers.contains(.control) { display += "⌃" }
        if maskedModifiers.contains(.option) { display += "⌥" }
        if maskedModifiers.contains(.shift) { display += "⇧" }
        if maskedModifiers.contains(.command) { display += "⌘" }
        display += keyLabel.isEmpty ? Self.fallbackSymbol(for: keyCode) : keyLabel
        return display
    }

    static func load(descriptor: GlobalShortcutDescriptor, from defaults: UserDefaults = .standard) -> GlobalShortcut {
        guard defaults.object(forKey: descriptor.keyCodeKey) != nil else {
            return descriptor.defaultValue
        }

        let keyCode = UInt16(clamping: defaults.integer(forKey: descriptor.keyCodeKey))
        let rawModifiers = UInt(clamping: max(0, defaults.integer(forKey: descriptor.modifiersKey)))
        let modifiers = NSEvent.ModifierFlags(rawValue: rawModifiers)
        let keyLabel = defaults.string(forKey: descriptor.keyLabelKey) ?? ""
        return GlobalShortcut(keyCode: keyCode, modifiers: modifiers, keyLabel: keyLabel)
    }

    func save(descriptor: GlobalShortcutDescriptor, to defaults: UserDefaults = .standard) {
        let maskedModifiers = modifiers.intersection(.deviceIndependentFlagsMask)
        defaults.set(Int(keyCode), forKey: descriptor.keyCodeKey)
        defaults.set(Int(maskedModifiers.rawValue), forKey: descriptor.modifiersKey)
        defaults.set(keyLabel, forKey: descriptor.keyLabelKey)
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
