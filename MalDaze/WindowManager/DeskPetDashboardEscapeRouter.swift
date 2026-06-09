import SwiftUI

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

extension View {
    /// 在 Esc 分级栈中登记弹出层；`isPresented` 为真时 Esc 优先调用 `onDismiss`。
    func deskPetDashboardEscapeOverlay(
        id: String,
        isPresented: Bool,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(DeskPetDashboardEscapeOverlayModifier(id: id, isPresented: isPresented, onDismiss: onDismiss))
    }
}
