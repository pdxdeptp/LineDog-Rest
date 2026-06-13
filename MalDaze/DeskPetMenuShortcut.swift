import AppKit
import Foundation

/// 全局「桌宠菜单」快捷键：持久化 keyCode + 修饰键；默认 ⌘⇧.（ANSI Period，keyCode 47）。
struct DeskPetMenuShortcut: Equatable {
    private var shortcut: GlobalShortcut

    var keyCode: UInt16 {
        get { shortcut.keyCode }
        set { shortcut.keyCode = newValue }
    }

    var modifiers: NSEvent.ModifierFlags {
        get { shortcut.modifiers }
        set { shortcut.modifiers = newValue }
    }

    /// 录制时的 `charactersIgnoringModifiers` 首字符，用于展示（与物理键位布局一致）。
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

    static let defaultKeyCode: UInt16 = 47

    static var defaultModifiers: NSEvent.ModifierFlags { [.command, .shift] }

    static var `default`: DeskPetMenuShortcut {
        DeskPetMenuShortcut(Self.descriptor.defaultValue)
    }

    /// 写入 UserDefaults 用的修饰键整型（与 `load` / `save` 一致）。
    static var defaultModifiersStorageInt: Int {
        Self.descriptor.defaultModifiersStorageInt
    }

    var isEnabled: Bool {
        shortcut.isEnabled
    }

    static func load(from defaults: UserDefaults = .standard) -> DeskPetMenuShortcut {
        DeskPetMenuShortcut(GlobalShortcut.load(descriptor: Self.descriptor, from: defaults))
    }

    func save(to defaults: UserDefaults = .standard) {
        shortcut.save(descriptor: Self.descriptor, to: defaults)
    }

    func matches(_ event: NSEvent) -> Bool {
        guard isEnabled else { return false }
        guard event.type == .keyDown else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let want = modifiers.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == keyCode && flags.rawValue == want.rawValue
    }

    var displayString: String {
        shortcut.displayString
    }

    private static var descriptor: GlobalShortcutDescriptor {
        GlobalShortcutDescriptor(
            keyCodeKey: MalDazeDefaults.deskPetMenuShortcutKeyCode,
            modifiersKey: MalDazeDefaults.deskPetMenuShortcutModifiers,
            keyLabelKey: MalDazeDefaults.deskPetMenuShortcutKeyLabel,
            defaultValue: GlobalShortcut(keyCode: defaultKeyCode, modifiers: defaultModifiers, keyLabel: ".")
        )
    }
}
