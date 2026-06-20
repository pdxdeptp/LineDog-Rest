import AppKit
import SwiftUI

enum TodayTodoInlineTextLayout {
    static let font = NSFont.preferredFont(forTextStyle: .body)
    static let lineSpacing: CGFloat = 1
    static let containerInset = NSSize(width: 0, height: 0)
}

/// 备忘录式行内编辑：无边框、同字体，点击出现光标，失焦保存。
struct TodayTodoInlineText: NSViewRepresentable {
    @Binding var text: String
    var isEditing: Bool
    var isCompleted: Bool
    var onBeginEditing: () -> Void
    var onCommit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> InlineNotesTextContainer {
        let container = InlineNotesTextContainer()
        container.configure(coordinator: context.coordinator)
        return container
    }

    func updateNSView(_ nsView: InlineNotesTextContainer, context: Context) {
        context.coordinator.parent = self
        nsView.sync(
            text: text,
            isEditing: isEditing,
            isCompleted: isCompleted,
            onBeginEditing: onBeginEditing
        )
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TodayTodoInlineText

        init(parent: TodayTodoInlineText) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textDidEndEditing(_ notification: Notification) {
            guard parent.isEditing else { return }
            parent.onCommit()
        }
    }
}

final class InlineNotesTextView: NSTextView {
    var onBeginEditingWithEvent: ((NSEvent) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if !isEditable {
            onBeginEditingWithEvent?(event)
            return
        }
        super.mouseDown(with: event)
    }
}

final class InlineNotesTextContainer: NSView {
    fileprivate let textView = InlineNotesTextView()
    private weak var coordinator: TodayTodoInlineText.Coordinator?
    private var isLocallyEditing = false
    private var isCompleted = false
    private var onBeginEditing: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isRichText = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = TodayTodoInlineTextLayout.containerInset
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.font = TodayTodoInlineTextLayout.font
        textView.focusRingType = .none
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.allowsUndo = true

        addSubview(textView)
        setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(coordinator: TodayTodoInlineText.Coordinator) {
        self.coordinator = coordinator
        textView.delegate = coordinator
    }

    func sync(
        text: String,
        isEditing: Bool,
        isCompleted: Bool,
        onBeginEditing: @escaping () -> Void
    ) {
        self.isCompleted = isCompleted
        self.onBeginEditing = onBeginEditing

        textView.onBeginEditingWithEvent = { [weak self] event in
            self?.beginEditing(with: event)
        }

        if !isEditing, textView.window?.firstResponder !== textView {
            isLocallyEditing = false
        }

        let active = isEditing || isLocallyEditing
        let isFirstResponder = textView.window?.firstResponder === textView

        if textView.string != text, !isFirstResponder {
            textView.string = text
        }

        textView.isEditable = active
        textView.isSelectable = active
        if !(active && isFirstResponder) {
            applyDisplayAttributes(isCompleted: isCompleted, isEditing: active)
        }

        if isEditing, !isFirstResponder {
            focusTextView(selecting: textView.string.utf16.count)
        } else if !isEditing {
            TodayTodoEditingFocus.clearIfActive(textView)
        }

        invalidateIntrinsicContentSize()
    }

    private func beginEditing(with event: NSEvent) {
        onBeginEditing?()

        isLocallyEditing = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.undoManager?.removeAllActions()
        applyDisplayAttributes(isCompleted: isCompleted, isEditing: true)

        window?.makeFirstResponder(textView)
        TodayTodoEditingFocus.activeView = textView

        let point = textView.convert(event.locationInWindow, from: nil)
        let index = textView.characterIndexForInsertion(at: point)
        textView.setSelectedRange(NSRange(location: index, length: 0))
        textView.scrollRangeToVisible(textView.selectedRange())
    }

    private func focusTextView(selecting index: Int) {
        guard textView.isEditable else { return }
        window?.makeFirstResponder(textView)
        TodayTodoEditingFocus.activeView = textView
        let clamped = min(max(index, 0), (textView.string as NSString).length)
        textView.setSelectedRange(NSRange(location: clamped, length: 0))
    }

    override var intrinsicContentSize: NSSize {
        let natural = measuredIntrinsicContentSize()
        return NSSize(width: NSView.noIntrinsicMetric, height: natural.height)
    }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        superview?.needsLayout = true
    }

    private func measuredIntrinsicContentSize() -> NSSize {
        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager
        else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 18)
        }
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        let inset = textView.textContainerInset
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: max(ceil(used.height + inset.height * 2), 18)
        )
    }

    private func applyDisplayAttributes(isCompleted: Bool, isEditing: Bool) {
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        guard fullRange.length > 0 else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = TodayTodoInlineTextLayout.lineSpacing

        var attrs: [NSAttributedString.Key: Any] = [
            .font: TodayTodoInlineTextLayout.font,
            .paragraphStyle: paragraph,
        ]

        if isCompleted && !isEditing {
            attrs[.foregroundColor] = NSColor.secondaryLabelColor
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        } else {
            attrs[.foregroundColor] = NSColor.labelColor
            attrs[.strikethroughStyle] = 0
        }

        textView.textStorage?.setAttributes(attrs, range: fullRange)
    }
}

enum TodayTodoEditingFocus {
    static weak var activeView: NSView?

    static func clearIfActive(_ view: NSView) {
        if activeView === view {
            activeView = nil
        }
    }

    static func isClickInsideActiveView(_ event: NSEvent) -> Bool {
        guard let view = activeView, let window = view.window else { return false }
        guard let hit = window.contentView?.hitTest(event.locationInWindow) else { return false }
        var node: NSView? = hit
        while let current = node {
            if current === view { return true }
            node = current.superview
        }
        return false
    }
}

/// 编辑中点击 todo 区块外时提交并收起光标。
final class TodayTodoEditingDismissMonitor {
    private var monitor: Any?

    func start(onDismiss: @escaping () -> Void) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard TodayTodoEditingFocus.activeView != nil else { return event }
            if TodayTodoEditingFocus.isClickInsideActiveView(event) {
                return event
            }
            onDismiss()
            NSApp.keyWindow?.makeFirstResponder(nil)
            TodayTodoEditingFocus.activeView = nil
            return event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
