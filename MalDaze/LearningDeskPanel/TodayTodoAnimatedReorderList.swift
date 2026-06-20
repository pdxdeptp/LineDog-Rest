import SwiftUI

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

    private var displayOrder: [UUID] {
        if controller.previewOrder.isEmpty {
            return entries.map(\.id)
        }
        return controller.previewOrder
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
            .onPreferenceChange(TodayTodoRowFramePreferenceKey.self) { frames in
                controller.updateRowFrames(frames)
            }
            .preference(
                key: TodayTodoReorderEdgeScrollPreferenceKey.self,
                value: TodayTodoReorderEdgeScrollPreference(
                    direction: controller.edgeScrollDirection,
                    targetEntryId: controller.edgeScrollTargetId
                )
            )

            TodayTodoListPointerReader { view in
                controller.listPointerView = view
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)

            if let draggingEntryId = controller.draggingEntryId,
               let entry = entryLookup[draggingEntryId],
               let frame = controller.frozenRowFrames[draggingEntryId],
               controller.showsDragOverlay {
                rowContent(entry, true)
                    .frame(width: frame.width, alignment: .leading)
                    .offset(
                        x: frame.minX,
                        y: frame.minY + controller.draggedOverlayOffset(for: draggingEntryId)
                    )
                    .scaleEffect(controller.overlayScale(for: draggingEntryId))
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 2)
                    .animation(controller.springAnimation, value: controller.phase)
                    .animation(nil, value: controller.listPointerY)
                    .zIndex(1)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: listViewportHeight) { height in
            controller.updateListViewportHeight(height)
        }
        .onAppear {
            controller.updateListViewportHeight(listViewportHeight)
        }
    }

    @ViewBuilder
    private func rowSlot(for entry: TodayTodoEntry) -> some View {
        let isDragPlaceholder = controller.draggingEntryId == entry.id && controller.showsDragOverlay
        let offset = controller.rowOffset(for: entry.id, listRowSpacing: listRowSpacing)

        rowContent(entry, isDragPlaceholder)
            .opacity(isDragPlaceholder ? 0 : 1)
            .todayTodoRowFrame(id: entry.id, in: .named(TodayTodoReorderCoordinateSpace.list))
            .offset(y: offset)
            .animation(controller.springAnimation, value: controller.insertionIndex)
            .animation(controller.springAnimation, value: controller.previewOrder)
            .id(entry.id)
    }
}
