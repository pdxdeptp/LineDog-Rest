import SwiftUI

struct TodayTodoRow: View {
    let entry: TodayTodoEntry
    let isCompleted: Bool
    let isBusy: Bool
    let onToggleComplete: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onToggleComplete) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isCompleted ? Color.secondary : Color.primary)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel(isCompleted ? "标记为未完成" : "标记为完成")

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline)
                    .strikethrough(isCompleted, color: .secondary)
                    .foregroundStyle(isCompleted ? Color.secondary : Color.primary)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                if !isCompleted, let hint = TodayTodoFormatting.rolledFromHint(entry.rolledFromDateISO) {
                    Text(hint)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button("编辑…", action: onEdit)
                Button("删除", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(isBusy)
        }
        .padding(.vertical, 4)
    }
}
