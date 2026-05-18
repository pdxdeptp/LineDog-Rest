import AppKit
import SwiftUI

/// 默认 `NSPanel` 常为 `canBecomeKey == false`，无边框浮动窗无法成为第一响应者，`NSTextField`/SwiftUI `TextField` 不能打字。
private final class SmartReminderKeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - SwiftUI

private enum SmartReminderInputPanelLayout {
    static let width: CGFloat = 420
    static let verticalPadding: CGFloat = 14
    static let contentSpacing: CGFloat = 12
    static let inputMinHeight: CGFloat = 78
    static let inputMaxHeight: CGFloat = 112
    static let actionRowHeight: CGFloat = 32

    static var height: CGFloat {
        inputMaxHeight + verticalPadding * 2 + contentSpacing + actionRowHeight
    }
}

private struct SmartReminderInputPanelContent: View {
    @FocusState private var fieldFocused: Bool
    @State private var hasSubmitted = false
    /// 由 `WindowManager` 持有，关闭面板后仍保留，下次打开继续编辑。
    @Binding var draft: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SmartReminderInputPanelLayout.contentSpacing) {
            TextField("用自然语言说出待办，回车添加...", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .focused($fieldFocused)
                .frame(
                    minHeight: SmartReminderInputPanelLayout.inputMinHeight,
                    maxHeight: SmartReminderInputPanelLayout.inputMaxHeight,
                    alignment: .topLeading
                )
                .onSubmit { submitOnce() }
            HStack {
                Spacer(minLength: 0)
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Button("添加") {
                    submitOnce()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .frame(minHeight: SmartReminderInputPanelLayout.actionRowHeight)
        }
        .padding(SmartReminderInputPanelLayout.verticalPadding)
        .onAppear {
            DispatchQueue.main.async {
                fieldFocused = true
            }
        }
        .onExitCommand(perform: onCancel)
    }

    private func submitOnce() {
        guard !hasSubmitted else { return }
        hasSubmitted = true
        onSubmit(draft)
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

/// 智能提醒输入与结果气泡（PRD 3）；由 `WindowManager` 在主线程调用。
enum SmartReminderUIPanels {
    private static let positioningGap: CGFloat = 10
    private static let positioningMargin: CGFloat = 10

    static func makeInputPanel(
        draft: Binding<String>,
        onSubmit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) -> (panel: NSPanel, host: NSHostingController<AnyView>) {
        let root = SmartReminderInputPanelContent(
            draft: draft,
            onSubmit: onSubmit,
            onCancel: onCancel
        )
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        let host = NSHostingController(rootView: AnyView(root))
        host.view.translatesAutoresizingMaskIntoConstraints = true

        let w = SmartReminderInputPanelLayout.width
        let h = SmartReminderInputPanelLayout.height
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
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(anchor) }
            ?? NSScreen.screens.first { $0.frame.intersects(anchor) }
            ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let frame = frameTopCenter(anchor: anchor, size: size, visibleFrame: visibleFrame)
        panel.setFrame(frame, display: true)
    }

    static func frameTopCenter(anchor: NSRect, size: NSSize, visibleFrame: NSRect) -> NSRect {
        let maxWidth = max(visibleFrame.width - 2 * positioningMargin, 1)
        let maxHeight = max(visibleFrame.height - 2 * positioningMargin, 1)
        let width = min(size.width, maxWidth)
        let height = min(size.height, maxHeight)

        let minX = visibleFrame.minX + positioningMargin
        let maxX = visibleFrame.maxX - positioningMargin - width
        let unclampedX = anchor.midX - width / 2
        let x = clamp(unclampedX, lower: minX, upper: maxX)

        let aboveY = anchor.maxY + positioningGap
        let belowY = anchor.minY - positioningGap - height
        let preferredY = aboveY + height <= visibleFrame.maxY - positioningMargin ? aboveY : belowY
        let minY = visibleFrame.minY + positioningMargin
        let maxY = visibleFrame.maxY - positioningMargin - height
        let y = clamp(preferredY, lower: minY, upper: maxY)

        return NSRect(x: x, y: y, width: width, height: height)
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
