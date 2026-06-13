import AppKit
import Foundation

/// 全局「添加提醒 / 智能输入」对话框快捷键；默认 ⌘⇧<（逗号键 + Shift，keyCode 43）。
struct SmartReminderInputShortcut: Equatable {
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

    static let defaultKeyCode: UInt16 = 43 // kVK_ANSI_Comma（与 Shift 组合为 <）

    static var defaultModifiers: NSEvent.ModifierFlags { [.command, .shift] }

    static var `default`: SmartReminderInputShortcut {
        SmartReminderInputShortcut(Self.descriptor.defaultValue)
    }

    static var defaultModifiersStorageInt: Int {
        Self.descriptor.defaultModifiersStorageInt
    }

    var isEnabled: Bool {
        shortcut.isEnabled
    }

    static func load(from defaults: UserDefaults = .standard) -> SmartReminderInputShortcut {
        SmartReminderInputShortcut(GlobalShortcut.load(descriptor: Self.descriptor, from: defaults))
    }

    func save(to defaults: UserDefaults = .standard) {
        shortcut.save(descriptor: Self.descriptor, to: defaults)
    }

    var displayString: String {
        shortcut.displayString
    }

    private static var descriptor: GlobalShortcutDescriptor {
        GlobalShortcutDescriptor(
            keyCodeKey: MalDazeDefaults.smartReminderInputShortcutKeyCode,
            modifiersKey: MalDazeDefaults.smartReminderInputShortcutModifiers,
            keyLabelKey: MalDazeDefaults.smartReminderInputShortcutKeyLabel,
            defaultValue: GlobalShortcut(keyCode: defaultKeyCode, modifiers: defaultModifiers, keyLabel: "<")
        )
    }
}
