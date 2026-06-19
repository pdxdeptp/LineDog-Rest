import SwiftUI

struct TodayTodoSection: View {
    @ObservedObject var store: TodayTodoStore
    @Binding var showHistory: Bool

    @State private var draft = ""
    @State private var draftFieldHeight = TodayTodoDraftFieldLayout.minHeight
    @State private var completedExpanded = false
    @State private var editingEntry: TodayTodoEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if case .error(let message) = store.loadState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let mutationError = store.mutationError {
                Text(mutationError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if store.canMutate {
                if store.incompleteEntries.isEmpty, store.completedEntries.isEmpty {
                    Text("随手记今天要做的小事，不会同步到提醒事项。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                ForEach(store.incompleteEntries) { entry in
                    TodayTodoRow(
                        entry: entry,
                        isCompleted: false,
                        isBusy: false,
                        onToggleComplete: { store.toggleComplete(id: entry.id) },
                        onEdit: { editingEntry = entry },
                        onDelete: { store.delete(id: entry.id) }
                    )
                }

                if !store.completedEntries.isEmpty {
                    DisclosureGroup(isExpanded: $completedExpanded) {
                        ForEach(store.completedEntries) { entry in
                            TodayTodoRow(
                                entry: entry,
                                isCompleted: true,
                                isBusy: false,
                                onToggleComplete: { store.toggleComplete(id: entry.id) },
                                onEdit: { editingEntry = entry },
                                onDelete: { store.delete(id: entry.id) }
                            )
                        }
                    } label: {
                        Text("已完成 \(store.completedEntries.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                TodayTodoDraftField(
                    text: $draft,
                    placeholder: "Shift+回车换行，回车添加…",
                    onSubmit: submitDraft,
                    height: $draftFieldHeight
                )
                .frame(height: draftFieldHeight)
                .disabled(!store.canMutate)
            }
        }
        .task {
            store.loadAndRollForward()
        }
        .alert("编辑条目", isPresented: editingPresented) {
            TextField("标题", text: editingTitle)
            Button("保存") {
                if let entry = editingEntry {
                    store.updateTitle(id: entry.id, title: editingTitle.wrappedValue)
                }
                editingEntry = nil
            }
            Button("取消", role: .cancel) {
                editingEntry = nil
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("今日 todo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if store.canMutate {
                Button("历史") {
                    showHistory = true
                }
                .controlSize(.small)
            }
            if !store.incompleteEntries.isEmpty {
                Text("\(store.incompleteEntries.count) 条")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var editingPresented: Binding<Bool> {
        Binding(
            get: { editingEntry != nil },
            set: { if !$0 { editingEntry = nil } }
        )
    }

    private var editingTitle: Binding<String> {
        Binding(
            get: { editingEntry?.title ?? "" },
            set: { newValue in
                guard var entry = editingEntry else { return }
                entry.title = newValue
                editingEntry = entry
            }
        )
    }

    private func submitDraft() {
        guard store.add(title: draft) else { return }
        draft = ""
        draftFieldHeight = TodayTodoDraftFieldLayout.minHeight
    }
}
