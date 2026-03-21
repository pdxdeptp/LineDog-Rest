import AppKit
import SwiftUI

/// 默认 `NSPanel` 常为 `canBecomeKey == false`，无边框浮动窗无法成为第一响应者，`NSTextField`/SwiftUI `TextField` 不能打字。
private final class SmartReminderKeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - SwiftUI

private struct SmartReminderInputPanelContent: View {
    @FocusState private var fieldFocused: Bool
    @State private var text = ""
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("用自然语言说出待办，回车添加…", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .frame(width: 400)
                .onSubmit { onSubmit(text) }
            HStack {
                Spacer(minLength: 0)
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .onAppear {
            DispatchQueue.main.async {
                fieldFocused = true
            }
        }
        .onExitCommand(perform: onCancel)
    }
}

private struct SmartReminderToastContent: View {
    let message: String
    let showUndo: Bool
    let onUndo: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: 300, alignment: .leading)
            if showUndo {
                Button("撤销 ↩") {
                    onUndo()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
    }
}

// MARK: - NSHosting panels

/// 单行输入与结果气泡（PRD 3）；由 `WindowManager` 在主线程调用。
enum SmartReminderUIPanels {
    static func makeInputPanel(
        onSubmit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) -> (panel: NSPanel, host: NSHostingController<AnyView>) {
        let root = SmartReminderInputPanelContent(
            onSubmit: onSubmit,
            onCancel: onCancel
        )
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        let host = NSHostingController(rootView: AnyView(root))
        host.view.translatesAutoresizingMaskIntoConstraints = true

        let w: CGFloat = 428
        let h: CGFloat = 96
        let panel = SmartReminderKeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating
        // 与桌宠窗一致避免 `fullScreenAuxiliary` 在多屏下的合成异常；须能 becomeKey 以接收输入。
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        host.view.frame = NSRect(x: 0, y: 0, width: w, height: h)
        host.view.autoresizingMask = [.width, .height]
        panel.contentView = host.view
        return (panel, host)
    }

    static func makeToastPanel(
        message: String,
        showUndo: Bool,
        onUndo: @escaping () -> Void
    ) -> (panel: NSPanel, host: NSHostingController<AnyView>, size: NSSize) {
        let root = SmartReminderToastContent(message: message, showUndo: showUndo, onUndo: onUndo)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        let host = NSHostingController(rootView: AnyView(root))
        host.view.translatesAutoresizingMaskIntoConstraints = true
        host.view.layoutSubtreeIfNeeded()
        var fitting = host.view.fittingSize
        if fitting.width < 32 { fitting.width = 320 }
        if fitting.height < 32 { fitting.height = 52 }
        let w = min(520, max(320, fitting.width + 16))
        let h = max(52, fitting.height + 16)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        host.view.frame = NSRect(x: 0, y: 0, width: w, height: h)
        panel.contentView = host.view
        return (panel, host, NSSize(width: w, height: h))
    }

    /// 将面板顶边中点置于 `anchor` 上方（屏幕坐标，Y 向上）。
    static func positionPanelTopCenter(_ panel: NSWindow, anchor: NSRect, size: NSSize) {
        let x = anchor.midX - size.width / 2
        let gap: CGFloat = 10
        let y = anchor.maxY + gap
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}
