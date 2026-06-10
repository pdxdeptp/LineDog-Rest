import AppKit
import SwiftUI

/// 系统 `confirmationDialog` / `alert` 默认不吃 Return；弹出时用本地监听补回车确认。
final class ConfirmationReturnKeyMonitor {
    private var monitor: Any?
    private let onConfirm: () -> Void

    init(onConfirm: @escaping () -> Void) {
        self.onConfirm = onConfirm
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard Self.isReturnKey(event) else { return event }
            guard event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty else {
                return event
            }
            self.onConfirm()
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private static func isReturnKey(_ event: NSEvent) -> Bool {
        event.keyCode == 36 || event.keyCode == 76
    }
}

/// 桌宠 Dashboard 内 Esc 分级：先关闭已登记的 sheet / 对话框，再关整个面板（由 `WindowManager` 消费）。
@MainActor
final class DeskPetDashboardEscapeRouter: ObservableObject {
    private var stack: [(id: String, dismiss: () -> Void)] = []

    var hasOpenOverlay: Bool { !stack.isEmpty }

    func register(id: String, dismiss: @escaping () -> Void) {
        unregister(id: id)
        stack.append((id, dismiss))
    }

    func unregister(id: String) {
        stack.removeAll { $0.id == id }
    }

    func reset() {
        stack.removeAll()
    }

    /// 关闭栈顶弹出层；返回 `true` 表示 Esc 已被消费。
    @discardableResult
    func consumeEscape() -> Bool {
        guard let top = stack.last else { return false }
        top.dismiss()
        return true
    }
}

private struct DeskPetDashboardEscapeOverlayModifier: ViewModifier {
    @EnvironmentObject private var escapeRouter: DeskPetDashboardEscapeRouter
    let id: String
    let isPresented: Bool
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear { syncRegistration(presented: isPresented) }
            .onChange(of: isPresented) { presented in
                syncRegistration(presented: presented)
            }
            .onDisappear {
                escapeRouter.unregister(id: id)
            }
    }

    private func syncRegistration(presented: Bool) {
        if presented {
            escapeRouter.register(id: id, dismiss: onDismiss)
        } else {
            escapeRouter.unregister(id: id)
        }
    }
}

private struct ConfirmationReturnKeyModifier: ViewModifier {
    let isPresented: Bool
    let onConfirm: () -> Void
    @State private var keyMonitor: ConfirmationReturnKeyMonitor?

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { presented in
                syncMonitor(presented: presented)
            }
            .onDisappear {
                keyMonitor?.stop()
                keyMonitor = nil
            }
    }

    private func syncMonitor(presented: Bool) {
        if presented {
            keyMonitor?.stop()
            let monitor = ConfirmationReturnKeyMonitor(onConfirm: onConfirm)
            monitor.start()
            keyMonitor = monitor
        } else {
            keyMonitor?.stop()
            keyMonitor = nil
        }
    }
}

extension View {
    /// 在 Esc 分级栈中登记弹出层；`isPresented` 为真时 Esc 优先调用 `onDismiss`。
    func deskPetDashboardEscapeOverlay(
        id: String,
        isPresented: Bool,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(DeskPetDashboardEscapeOverlayModifier(id: id, isPresented: isPresented, onDismiss: onDismiss))
    }

    /// 确认框展示期间，无修饰 Return / 小键盘 Enter 触发 `onConfirm`。
    func confirmationReturnKey(isPresented: Bool, onConfirm: @escaping () -> Void) -> some View {
        modifier(ConfirmationReturnKeyModifier(isPresented: isPresented, onConfirm: onConfirm))
    }
}
