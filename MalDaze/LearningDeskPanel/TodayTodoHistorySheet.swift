import SwiftUI

struct TodayTodoHistorySheet: View {
    @ObservedObject var store: TodayTodoStore
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("历史")
                .font(.headline)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    trashSection

                    let sections = store.historyGroupedByDate()
                    if sections.isEmpty {
                        if store.deletedEntries.isEmpty {
                            Text("暂无历史已完成条目。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        }
                    } else {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(TodayTodoFormatting.historySectionTitle(section.dateISO))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(section.entries) { entry in
                                    historyRow(
                                        title: entry.title,
                                        subtitle: nil,
                                        onDelete: { store.delete(id: entry.id) }
                                    )
                                }
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("关闭", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .frame(minHeight: 280, maxHeight: 480)
    }

    @ViewBuilder
    private var trashSection: some View {
        if !store.deletedEntries.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("最近删除", systemImage: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(store.deletedEntries) { entry in
                    trashRow(entry)
                }
            }
        }
    }

    private func trashRow(_ entry: TodayTodoEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let deletedAt = entry.deletedAt {
                    Text(TodayTodoFormatting.deletedAtHint(deletedAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Button("恢复") {
                store.restore(id: entry.id)
            }
            .controlSize(.small)

            Button(role: .destructive) {
                store.permanentlyDelete(id: entry.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("彻底删除")
        }
    }

    private func historyRow(title: String, subtitle: String?, onDelete: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .strikethrough(true, color: .secondary)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
    }
}
