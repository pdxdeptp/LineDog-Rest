import AppKit

/// Dashboard 内无修饰 `1`–`9` 快捷记录饮食建议项。
final class NutritionDigitKeyMonitor {
    private var monitor: Any?
    private let onDigit: (Int) -> Void
    private let isEnabled: () -> Bool

    init(
        isEnabled: @escaping () -> Bool,
        onDigit: @escaping (Int) -> Void
    ) {
        self.isEnabled = isEnabled
        self.onDigit = onDigit
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.isEnabled(), !Self.isTextInputFocused() else { return event }
            guard event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty else {
                return event
            }
            guard let character = event.charactersIgnoringModifiers, character.count == 1,
                  let digit = Int(character), (1...9).contains(digit)
            else {
                return event
            }
            self.onDigit(digit)
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private static func isTextInputFocused() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return responder is NSTextView || responder is NSTextField || responder is NSTextInputClient
    }
}
