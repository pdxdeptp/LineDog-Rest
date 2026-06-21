import AppKit
import SwiftUI

enum TodayTodoRowLayout {
    static let leadingControlSpacing: CGFloat = 6

    /// Matches the complete-circle control width in todo rows for draft/text column alignment.
    static var leadingGutter: some View {
        Image(systemName: "circle")
            .font(.title3)
            .opacity(0)
            .accessibilityHidden(true)
    }
}

struct TodayTodoRow: View {
    let entry: TodayTodoEntry
    let isCompleted: Bool
    let isEditing: Bool
    @Binding var editingText: String
    let isBusy: Bool
    var reorderGestureEnabled: Bool = false
    var onReorderPressingReady: ((NSEvent) -> Void)? = nil
    var onReorderActivated: ((NSEvent) -> Void)? = nil
    var onReorderDrag: ((NSEvent) -> Void)? = nil
    var onReorderEnded: (() -> Void)? = nil
    let onToggleComplete: () -> Void
    let onBeginEdit: () -> Void
    let onCommitEdit: () -> Void
    var onLiveEdit: ((String) -> Void)? = nil
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: TodayTodoRowLayout.leadingControlSpacing) {
            Button(action: onToggleComplete) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? Color.secondary : Color.primary)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel(isCompleted ? "标记为未完成" : "标记为完成")

            TodayTodoInlineText(
                text: isEditing ? $editingText : .constant(entry.title),
                isEditing: isEditing,
                isCompleted: isCompleted,
                reorderGestureEnabled: reorderGestureEnabled,
                onBeginEditing: onBeginEdit,
                onCommit: onCommitEdit,
                onLiveEdit: onLiveEdit,
                onReorderPressingReady: onReorderPressingReady,
                onReorderActivated: onReorderActivated,
                onReorderDrag: onReorderDrag,
                onReorderEnded: onReorderEnded
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(isBusy)
            .help("删除")
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 1)
    }
}
