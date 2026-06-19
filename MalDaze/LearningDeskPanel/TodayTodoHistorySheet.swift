import SwiftUI

struct TodayTodoHistorySheet: View {
    @ObservedObject var store: TodayTodoStore
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("历史")
                .font(.headline)

            let sections = store.historyGroupedByDate()
            if sections.isEmpty {
                Text("暂无历史已完成条目。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(TodayTodoFormatting.historySectionTitle(section.dateISO))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(section.entries) { entry in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(entry.title)
                                            .font(.subheadline)
                                            .strikethrough(true, color: .secondary)
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Button(role: .destructive) {
                                            store.delete(id: entry.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.borderless)
                                    }
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
}
