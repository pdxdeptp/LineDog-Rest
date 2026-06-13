import AppKit
import Foundation

/// 全局「桌宠回到菜单栏屏可见区右下角」；默认 ⌘⇧R（ANSI R，keyCode 15）。
struct ResetIdlePetPositionShortcut: Equatable {
    private var shortcut: GlobalShortcut

    var keyCode: UInt16 {
        get { shortcut.keyCode }
        set { shortcut.keyCode = newValue }
    }

    var modifiers: NSEvent.ModifierFlags {
        get { shortcut.modifiers }
        set { shortcut.modifiers = newValue }
    }

    var keyLabel: String {
        get { shortcut.keyLabel }
        set { shortcut.keyLabel = newValue }
    }

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, keyLabel: String) {
        shortcut = GlobalShortcut(keyCode: keyCode, modifiers: modifiers, keyLabel: keyLabel)
    }

    private init(_ shortcut: GlobalShortcut) {
        self.shortcut = shortcut
    }

    static let defaultKeyCode: UInt16 = 15 // kVK_ANSI_R

    static var defaultModifiers: NSEvent.ModifierFlags { [.command, .shift] }

    static var `default`: ResetIdlePetPositionShortcut {
        ResetIdlePetPositionShortcut(Self.descriptor.defaultValue)
    }

    static var defaultModifiersStorageInt: Int {
        Self.descriptor.defaultModifiersStorageInt
    }

    var isEnabled: Bool {
        shortcut.isEnabled
    }

    static func load(from defaults: UserDefaults = .standard) -> ResetIdlePetPositionShortcut {
        ResetIdlePetPositionShortcut(GlobalShortcut.load(descriptor: Self.descriptor, from: defaults))
    }

    func save(to defaults: UserDefaults = .standard) {
        shortcut.save(descriptor: Self.descriptor, to: defaults)
    }

    var displayString: String {
        shortcut.displayString
    }

    private static var descriptor: GlobalShortcutDescriptor {
        GlobalShortcutDescriptor(
            keyCodeKey: MalDazeDefaults.resetIdlePetShortcutKeyCode,
            modifiersKey: MalDazeDefaults.resetIdlePetShortcutModifiers,
            keyLabelKey: MalDazeDefaults.resetIdlePetShortcutKeyLabel,
            defaultValue: GlobalShortcut(keyCode: defaultKeyCode, modifiers: defaultModifiers, keyLabel: "R")
        )
    }
}
