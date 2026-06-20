import AppKit
import SwiftUI

enum DashboardResizeHandleLineLayout {
    static let thickness: CGFloat = 3
    static let opacity: CGFloat = 0.55

    static func centeredLineOrigin(in extent: CGFloat) -> CGFloat {
        floor((extent - thickness) / 2)
    }
}

enum DashboardResizeHandleAxis {
    case columns
    case rows
}

final class DashboardColumnResizeHandleView: NSView {
    var axis: DashboardResizeHandleAxis = .columns
    var onDragChanged: ((CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?
    private var lastDragValue: CGFloat = 0
    private var isDragging = false
    private var trackingArea: NSTrackingArea?
    private var installedTrackingBounds: NSRect = .null
    private var hoverCursorActive = false
    private var dragCursorActive = false

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    private var resizeCursor: NSCursor {
        axis == .columns ? .resizeLeftRight : .resizeUpDown
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: resizeCursor)
    }

    override func layout() {
        super.layout()
        installTrackingAreaIfNeeded()
        resetCursorRects()
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        installTrackingAreaIfNeeded()
        resetCursorRects()
    }

    override func cursorUpdate(with event: NSEvent) {
        guard !isDragging else { return }
        resizeCursor.set()
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isDragging else { return }
        resizeCursor.push()
        hoverCursorActive = true
    }

    override func mouseExited(with event: NSEvent) {
        guard !isDragging, hoverCursorActive else { return }
        NSCursor.pop()
        hoverCursorActive = false
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.withAlphaComponent(DashboardResizeHandleLineLayout.opacity).setFill()
        let thickness = DashboardResizeHandleLineLayout.thickness
        switch axis {
        case .columns:
            let x = DashboardResizeHandleLineLayout.centeredLineOrigin(in: bounds.width)
            NSRect(x: x, y: 0, width: thickness, height: bounds.height).fill()
        case .rows:
            let y = DashboardResizeHandleLineLayout.centeredLineOrigin(in: bounds.height)
            NSRect(x: 0, y: y, width: bounds.width, height: thickness).fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        lastDragValue = dragCoordinate(for: event)
        isDragging = true
        if !hoverCursorActive {
            resizeCursor.push()
            dragCursorActive = true
        }
        resizeCursor.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let value = dragCoordinate(for: event)
        let delta = value - lastDragValue
        lastDragValue = value
        guard abs(delta) > 0.01 else { return }
        onDragChanged?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        lastDragValue = 0
        onDragEnded?()

        if dragCursorActive {
            NSCursor.pop()
            dragCursorActive = false
        }

        let localPoint = convert(event.locationInWindow, from: nil)
        if bounds.contains(localPoint) {
            resizeCursor.set()
        } else if hoverCursorActive {
            NSCursor.pop()
            hoverCursorActive = false
        }
    }

    private func dragCoordinate(for event: NSEvent) -> CGFloat {
        switch axis {
        case .columns:
            return event.locationInWindow.x
        case .rows:
            return -event.locationInWindow.y
        }
    }

    private func installTrackingAreaIfNeeded() {
        guard !NSEqualRects(bounds, installedTrackingBounds) else { return }
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [
            .activeInKeyWindow,
            .mouseEnteredAndExited,
            .cursorUpdate,
            .inVisibleRect,
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
        installedTrackingBounds = bounds
    }
}

struct DashboardResizeHandleChrome: NSViewRepresentable {
    var axis: DashboardResizeHandleAxis
    var onDragChanged: (CGFloat) -> Void
    var onDragEnded: () -> Void

    func makeNSView(context: Context) -> DashboardColumnResizeHandleView {
        let view = DashboardColumnResizeHandleView()
        view.axis = axis
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
        return view
    }

    func updateNSView(_ nsView: DashboardColumnResizeHandleView, context: Context) {
        nsView.axis = axis
        nsView.onDragChanged = onDragChanged
        nsView.onDragEnded = onDragEnded
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: DashboardColumnResizeHandleView, context: Context) -> CGSize? {
        switch axis {
        case .columns:
            return CGSize(
                width: DashboardLayout.columnResizeHandleWidth,
                height: proposal.height ?? nsView.bounds.height
            )
        case .rows:
            return CGSize(
                width: proposal.width ?? nsView.bounds.width,
                height: DashboardLayout.columnResizeHandleWidth
            )
        }
    }
}

struct DashboardColumnResizeHandleChrome: View {
    var onDragChanged: (CGFloat) -> Void
    var onDragEnded: () -> Void

    var body: some View {
        DashboardResizeHandleChrome(
            axis: .columns,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded
        )
        .frame(width: DashboardLayout.columnResizeHandleWidth)
        .frame(maxHeight: .infinity)
        .accessibilityLabel(Text("调整分栏宽度"))
        .accessibilityAddTraits(.isButton)
    }
}

struct DashboardRowResizeHandleChrome: View {
    var accessibilityLabelText: String = "调整计划与饮食区高度"
    var onDragChanged: (CGFloat) -> Void
    var onDragEnded: () -> Void

    var body: some View {
        DashboardResizeHandleChrome(
            axis: .rows,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded
        )
        .frame(height: DashboardLayout.columnResizeHandleWidth)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text(accessibilityLabelText))
        .accessibilityAddTraits(.isButton)
    }
}

/// 上下分栏 + 可拖动行向 handle；`upperFraction` 为上方占可分配高度的比例。
struct DashboardVerticalFractionSplit<Upper: View, Lower: View>: View {
    var upperFraction: Double
    var handleAccessibilityLabel: String
    var handleID: String?
    var onFractionDragChanged: (CGFloat, CGFloat) -> Void
    var onFractionDragEnded: () -> Void
    @ViewBuilder var upper: () -> Upper
    @ViewBuilder var lower: (_ lowerHeight: CGFloat) -> Lower

    var body: some View {
        GeometryReader { geometry in
            let split = DashboardLayout.verticalSplitHeights(
                totalHeight: geometry.size.height,
                upperFraction: upperFraction
            )
            VStack(spacing: 0) {
                upper()
                    .frame(height: split.upper, alignment: .topLeading)
                    .clipped()
                DashboardRowResizeHandleChrome(
                    accessibilityLabelText: handleAccessibilityLabel,
                    onDragChanged: { onFractionDragChanged($0, split.stack) },
                    onDragEnded: onFractionDragEnded
                )
                .modifier(DashboardResizeHandleIDModifier(id: handleID))
                lower(split.lower)
                    .frame(height: split.lower, alignment: .topLeading)
                    .clipped()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct DashboardResizeHandleIDModifier: ViewModifier {
    let id: String?

    func body(content: Content) -> some View {
        if let id {
            content.id(id)
        } else {
            content
        }
    }
}
