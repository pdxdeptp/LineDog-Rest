import SwiftUI

struct TodayTodoRow: View {
    let entry: TodayTodoEntry
    let isCompleted: Bool
    let isEditing: Bool
    @Binding var editingText: String
    let isBusy: Bool
    let onToggleComplete: () -> Void
    let onBeginEdit: () -> Void
    let onCommitEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Button(action: onToggleComplete) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? Color.secondary : Color.primary)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel(isCompleted ? "标记为未完成" : "标记为完成")

            VStack(alignment: .leading, spacing: 1) {
                TodayTodoInlineText(
                    text: isEditing ? $editingText : .constant(entry.title),
                    isEditing: isEditing,
                    isCompleted: isCompleted,
                    onBeginEditing: onBeginEdit,
                    onCommit: onCommitEdit
                )
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
                .contentShape(Rectangle())

                if !isCompleted, !isEditing,
                   let hint = TodayTodoFormatting.rolledFromHint(entry.rolledFromDateISO) {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
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
