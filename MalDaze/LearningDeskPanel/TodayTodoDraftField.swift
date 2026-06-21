import AppKit
import SwiftUI

enum TodayTodoDraftFieldLayout {
    static let minHeight: CGFloat = 24
    static let maxHeight: CGFloat = 120
    static let horizontalInset: CGFloat = 0
    static let verticalInset: CGFloat = 2
    static let underlineGap: CGFloat = 2
    static let placeholderTextColor = NSColor.tertiaryLabelColor
    static let inputTextColor = NSColor.labelColor
}

/// 多行文本：回车提交/保存，⇧回车换行，高度随内容在 min/max 内增长；底部横线样式。
struct TodayTodoDraftField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Bool
    @Binding var height: CGFloat
    var focusRequestToken: Int = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> DraftScrollContainer {
        let container = DraftScrollContainer()
        container.configure(coordinator: context.coordinator)
        if focusRequestToken > 0 {
            context.coordinator.lastAppliedFocusToken = focusRequestToken
            container.scheduleFocus()
        }
        return container
    }

    func updateNSView(_ nsView: DraftScrollContainer, context: Context) {
        context.coordinator.parent = self
        nsView.updatePlaceholder(placeholder)
        nsView.syncTextIfNeeded(text)
        nsView.refreshHeight(reportTo: { height = $0 })
        if context.coordinator.lastAppliedFocusToken != focusRequestToken, focusRequestToken > 0 {
            context.coordinator.lastAppliedFocusToken = focusRequestToken
            nsView.scheduleFocus()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TodayTodoDraftField
        var lastAppliedFocusToken = 0

        init(parent: TodayTodoDraftField) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? DraftTextView else { return }
            parent.text = textView.string
            textView.enclosingScrollContainer()?.refreshHeight(reportTo: { self.parent.height = $0 })
        }
    }
}

final class DraftTextView: NSTextView {
    var onSubmit: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        if isReturn {
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift) {
                insertNewline(nil)
            } else {
                onSubmit?()
            }
            return
        }
        super.keyDown(with: event)
    }
}

final class DraftScrollContainer: NSView {
    private let scrollView = NSScrollView()
    private let textView = DraftTextView()
    private let underlineView = NSView()
    private var placeholderLabel: NSTextField?
    private weak var coordinator: TodayTodoDraftField.Coordinator?
    private var wantsFocus = false
    private var focusAttemptGeneration = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView.isRichText = false
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(
            width: TodayTodoDraftFieldLayout.horizontalInset,
            height: TodayTodoDraftFieldLayout.verticalInset
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.textColor = TodayTodoDraftFieldLayout.inputTextColor
        textView.typingAttributes = [
            .font: textView.font as Any,
            .foregroundColor: TodayTodoDraftFieldLayout.inputTextColor,
        ]
        textView.backgroundColor = .clear
        textView.focusRingType = .none
        textView.insertionPointColor = .labelColor
        textView.allowsUndo = true

        underlineView.wantsLayer = true
        underlineView.layer?.backgroundColor = NSColor.separatorColor.cgColor
        underlineView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = textView
        addSubview(scrollView)
        addSubview(underlineView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(
                equalTo: underlineView.topAnchor,
                constant: -TodayTodoDraftFieldLayout.underlineGap
            ),

            underlineView.leadingAnchor.constraint(equalTo: leadingAnchor),
            underlineView.trailingAnchor.constraint(equalTo: trailingAnchor),
            underlineView.bottomAnchor.constraint(equalTo: bottomAnchor),
            underlineView.heightAnchor.constraint(equalToConstant: 1),
        ])

        let placeholder = NSTextField(labelWithString: "")
        placeholder.textColor = TodayTodoDraftFieldLayout.placeholderTextColor
        placeholder.font = textView.font
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.lineBreakMode = .byTruncatingTail
        addSubview(placeholder)
        placeholderLabel = placeholder

        NSLayoutConstraint.activate([
            placeholder.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: TodayTodoDraftFieldLayout.horizontalInset
            ),
            placeholder.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -TodayTodoDraftFieldLayout.horizontalInset
            ),
            placeholder.topAnchor.constraint(
                equalTo: topAnchor,
                constant: TodayTodoDraftFieldLayout.verticalInset
            ),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(coordinator: TodayTodoDraftField.Coordinator) {
        self.coordinator = coordinator
        textView.delegate = coordinator
        textView.onSubmit = { [weak self] in
            guard let self else { return }
            let didSubmit = coordinator.parent.onSubmit()
            guard didSubmit else { return }
            self.textView.string = ""
            self.textView.undoManager?.removeAllActions()
            self.syncPlaceholderVisibility()
            self.refreshHeight(reportTo: { coordinator.parent.height = $0 })
        }
    }

    func updatePlaceholder(_ text: String) {
        placeholderLabel?.stringValue = text
        syncPlaceholderVisibility()
    }

    func syncTextIfNeeded(_ text: String) {
        guard textView.string != text else { return }
        let isFirstResponder = textView.window?.firstResponder === textView
        if text.isEmpty || !isFirstResponder {
            textView.string = text
            textView.textColor = TodayTodoDraftFieldLayout.inputTextColor
            textView.typingAttributes = [
                .font: textView.font as Any,
                .foregroundColor: TodayTodoDraftFieldLayout.inputTextColor,
            ]
            textView.undoManager?.removeAllActions()
            syncPlaceholderVisibility()
        }
    }

    func focusTextView() {
        scheduleFocus()
    }

    func scheduleFocus() {
        wantsFocus = true
        focusAttemptGeneration += 1
        runFocusAttempts(generation: focusAttemptGeneration, attempt: 0)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, wantsFocus else { return }
        scheduleFocus()
    }

    private func runFocusAttempts(generation: Int, attempt: Int) {
        guard generation == focusAttemptGeneration else { return }
        guard attempt < 14 else { return }

        let retry = { [weak self] in
            guard let self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.runFocusAttempts(generation: generation, attempt: attempt + 1)
            }
        }

        guard let window else {
            retry()
            return
        }

        if !window.isKeyWindow {
            NSApp.activate(ignoringOtherApps: true)
        }

        if window.firstResponder !== textView {
            window.makeFirstResponder(textView)
        }

        guard window.firstResponder === textView else {
            retry()
            return
        }

        wantsFocus = false
        let end = (textView.string as NSString).length
        textView.setSelectedRange(NSRange(location: end, length: 0))
        textView.scrollRangeToVisible(textView.selectedRange())
    }

    func refreshHeight(reportTo: (CGFloat) -> Void) {
        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager
        else { return }
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        let inset = textView.textContainerInset
        let underlineBlock = TodayTodoDraftFieldLayout.underlineGap + 1
        let raw = used.height + inset.height * 2 + underlineBlock
        let clamped = min(
            max(raw, TodayTodoDraftFieldLayout.minHeight),
            TodayTodoDraftFieldLayout.maxHeight
        )
        reportTo(clamped)
        scrollView.hasVerticalScroller = raw > TodayTodoDraftFieldLayout.maxHeight
    }

    private func syncPlaceholderVisibility() {
        placeholderLabel?.isHidden = !textView.string.isEmpty
    }
}

private extension NSView {
    func enclosingScrollContainer() -> DraftScrollContainer? {
        var view: NSView? = self
        while let current = view {
            if let container = current as? DraftScrollContainer { return container }
            view = current.superview
        }
        return nil
    }
}
