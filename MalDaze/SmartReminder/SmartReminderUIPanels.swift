import AppKit
import SwiftUI

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

// MARK: - Content builders

/// 智能提醒输入与结果气泡内容；panel shell 由 `MalDazeTransientOverlayPresenter` 创建。
enum SmartReminderUIPanels {
    static func makeInputContent(
        draft: Binding<String>,
        onSubmit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) -> TransientOverlayContent {
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
        host.view.frame = NSRect(x: 0, y: 0, width: w, height: h)
        host.view.autoresizingMask = [.width, .height]
        return TransientOverlayContent(
            view: host.view,
            size: NSSize(width: w, height: h),
            retainedObject: host
        )
    }

    static func makeToastContent(
        message: String,
        showUndo: Bool,
        onUndo: @escaping () -> Void
    ) -> TransientOverlayContent {
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
        host.view.frame = NSRect(x: 0, y: 0, width: w, height: h)
        return TransientOverlayContent(
            view: host.view,
            size: NSSize(width: w, height: h),
            retainedObject: host
        )
    }

    /// 测试与展示器共用同一 clamp 算法。
    static func frameTopCenter(anchor: NSRect, size: NSSize, visibleFrame: NSRect) -> NSRect {
        InteractiveAnchoredOverlayGeometry.frameTopCenter(
            anchor: anchor,
            size: size,
            visibleFrame: visibleFrame
        )
    }
}
