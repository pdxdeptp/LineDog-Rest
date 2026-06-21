import SwiftUI

private struct TodayTodoSpringCompletionModifier: AnimatableModifier {
    var progress: CGFloat
    let generation: UInt
    let onComplete: (UInt) -> Void

    var animatableData: CGFloat {
        get { progress }
        set {
            progress = newValue
            if newValue >= 1 {
                onComplete(generation)
            }
        }
    }

    func body(content: Content) -> some View {
        content
    }
}

private enum TodayTodoReorderCoordinateSpace {
    static let list = "todayTodoReorderList"
}

struct TodayTodoAnimatedReorderList<RowContent: View>: View {
    let entries: [TodayTodoEntry]
    let listRowSpacing: CGFloat
    let reorderEnabled: Bool
    let listViewportHeight: CGFloat
    @ObservedObject var controller: TodayTodoReorderController
    @ViewBuilder var rowContent: (TodayTodoEntry, Bool) -> RowContent

    @State private var settleAnimationProgress: CGFloat = 0

    private var displayOrder: [UUID] {
        controller.baseOrder.isEmpty ? entries.map(\.id) : controller.baseOrder
    }

    private var entryLookup: [UUID: TodayTodoEntry] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: listRowSpacing) {
                ForEach(displayOrder, id: \.self) { entryId in
                    if let entry = entryLookup[entryId] {
                        rowSlot(for: entry)
                    }
                }
            }
            .coordinateSpace(name: TodayTodoReorderCoordinateSpace.list)
            .background {
                TodayTodoWindowFrameReporter { frameInWindow in
                    controller.updateValidRegionInWindow(frameInWindow)
                }
            }
            .onPreferenceChange(TodayTodoRowFramePreferenceKey.self) { frames in
                controller.updateRowFrames(frames)
            }
            .preference(
                key: TodayTodoReorderEdgeScrollPreferenceKey.self,
                value: TodayTodoReorderEdgeScrollPreference(
                    velocity: controller.edgeScrollVelocity,
                    enabled: controller.isDragging
                )
            )

            TodayTodoListPointerReader(viewportHeight: listViewportHeight) { view in
                controller.listPointerView = view
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)

            if let indicatorY = controller.insertionIndicatorMinY,
               controller.isDragging || controller.phase == .settling {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.35))
                    .frame(height: TodayTodoReorderMetrics.insertionIndicatorThickness)
                    .offset(y: indicatorY)
                    .allowsHitTesting(false)
            }

            if let draggingEntryId = controller.draggingEntryId,
               let entry = entryLookup[draggingEntryId],
               let frame = controller.frozenRowFrames[draggingEntryId],
               let overlayMinY = controller.draggedOverlayMinY(for: draggingEntryId),
               controller.showsDragOverlay {
                TodayTodoDragPreview(
                    title: entry.title,
                    width: frame.width
                )
                .offset(x: frame.minX, y: overlayMinY)
                .scaleEffect(
                    controller.phase == .dragging ? TodayTodoReorderMetrics.liftScale : 1
                )
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 2)
                .modifier(
                    TodayTodoSpringCompletionModifier(
                        progress: settleAnimationProgress,
                        generation: controller.sessionGeneration,
                        onComplete: { generation in
                            guard generation == controller.sessionGeneration else { return }
                            controller.finishSettlingAnimation()
                        }
                    )
                )
                .animation(
                    controller.phase == .dragging ? nil : controller.springAnimation,
                    value: overlayMinY
                )
                .zIndex(1)
                .allowsHitTesting(false)
                .onChange(of: controller.phase) { phase in
                    if phase == .settling || phase == .cancelling {
                        settleAnimationProgress = 0
                        controller.notifySettlingAnimationStarted()
                        withAnimation(controller.springAnimation) {
                            settleAnimationProgress = 1
                        }
                    } else {
                        settleAnimationProgress = 0
                    }
                }
            }
        }
        .onChange(of: listViewportHeight) { height in
            controller.updateListViewportHeight(height)
        }
        .onChange(of: entries.map(\.id)) { ids in
            if !controller.validateEntriesIdentity(entries) {
                controller.invalidateSessionOnDisappear()
            }
            _ = ids
        }
        .onAppear {
            controller.updateListViewportHeight(listViewportHeight)
            controller.updateListRowSpacing(listRowSpacing)
        }
        .onDisappear {
            controller.invalidateSessionOnDisappear()
        }
    }

    @ViewBuilder
    private func rowSlot(for entry: TodayTodoEntry) -> some View {
        let isDragPlaceholder = controller.draggingEntryId == entry.id && controller.showsDragOverlay
        let isPressingSource = controller.showsPressingLift && controller.draggingEntryId == entry.id
        let offset = controller.rowOffset(for: entry.id)

        rowContent(entry, isDragPlaceholder)
            .opacity(isDragPlaceholder ? 0 : 1)
            .scaleEffect(isPressingSource ? TodayTodoReorderMetrics.liftScale : 1)
            .shadow(color: isPressingSource ? .black.opacity(0.12) : .clear, radius: 8, x: 0, y: 2)
            .todayTodoRowFrame(id: entry.id, in: .named(TodayTodoReorderCoordinateSpace.list))
            .offset(y: offset)
            .animation(controller.springAnimation, value: controller.targetIndex)
            .id(entry.id)
    }
}

/// Reports the hosting view's bounds in window coordinates for reorder exit detection.
private struct TodayTodoWindowFrameReporter: NSViewRepresentable {
    let onUpdate: (CGRect) -> Void

    func makeNSView(context: Context) -> ReportingView {
        ReportingView(onUpdate: onUpdate)
    }

    func updateNSView(_ nsView: ReportingView, context: Context) {
        nsView.onUpdate = onUpdate
        nsView.reportFrameIfNeeded()
    }

    final class ReportingView: NSView {
        var onUpdate: (CGRect) -> Void
        private var lastReportedFrame: CGRect = .null

        init(onUpdate: @escaping (CGRect) -> Void) {
            self.onUpdate = onUpdate
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportFrameIfNeeded()
        }

        override func layout() {
            super.layout()
            reportFrameIfNeeded()
        }

        func reportFrameIfNeeded() {
            guard window != nil else { return }
            let frameInWindow = convert(bounds, to: nil)
            guard frameInWindow != lastReportedFrame else { return }
            lastReportedFrame = frameInWindow
            onUpdate(frameInWindow)
        }
    }
}
