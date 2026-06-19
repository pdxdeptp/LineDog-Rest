import AppKit
import SwiftUI

enum TodayTodoDraftFieldLayout {
    static let minHeight: CGFloat = 28
    static let maxHeight: CGFloat = 120
    static let horizontalInset: CGFloat = 6
    static let verticalInset: CGFloat = 4
}

/// 多行草稿输入：回车提交，⇧回车换行，高度随内容在 min/max 内增长。
struct TodayTodoDraftField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> DraftScrollContainer {
        let container = DraftScrollContainer()
        container.configure(coordinator: context.coordinator)
        return container
    }

    func updateNSView(_ nsView: DraftScrollContainer, context: Context) {
        context.coordinator.parent = self
        nsView.updatePlaceholder(placeholder)
        nsView.syncTextIfNeeded(text)
        nsView.refreshHeight(reportTo: { height = $0 })
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TodayTodoDraftField

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
    private var placeholderLabel: NSTextField?
    private weak var coordinator: TodayTodoDraftField.Coordinator?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

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
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.backgroundColor = .clear

        scrollView.documentView = textView
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let placeholder = NSTextField(labelWithString: "")
        placeholder.textColor = .placeholderTextColor
        placeholder.font = textView.font
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.lineBreakMode = .byTruncatingTail
        addSubview(placeholder)
        placeholderLabel = placeholder

        NSLayoutConstraint.activate([
            placeholder.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: TodayTodoDraftFieldLayout.horizontalInset + 2
            ),
            placeholder.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -TodayTodoDraftFieldLayout.horizontalInset
            ),
            placeholder.topAnchor.constraint(
                equalTo: topAnchor,
                constant: TodayTodoDraftFieldLayout.verticalInset + 1
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
            coordinator.parent.onSubmit()
            self.syncPlaceholderVisibility()
        }
    }

    func updatePlaceholder(_ text: String) {
        placeholderLabel?.stringValue = text
        syncPlaceholderVisibility()
    }

    func syncTextIfNeeded(_ text: String) {
        if textView.string != text {
            textView.string = text
            syncPlaceholderVisibility()
        }
    }

    func refreshHeight(reportTo: (CGFloat) -> Void) {
        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager
        else { return }
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        let inset = textView.textContainerInset
        let raw = used.height + inset.height * 2 + 4
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
