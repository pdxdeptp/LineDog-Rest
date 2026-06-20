import SwiftUI

private enum TodayTodoSectionLayout {
    static let sectionSpacing: CGFloat = 6
    static let listRowSpacing: CGFloat = 2
}

struct TodayTodoSection: View {
    @ObservedObject var store: TodayTodoStore
    @Binding var showHistory: Bool
    var sectionHeight: CGFloat

    @State private var draft = ""
    @State private var draftFieldHeight = TodayTodoDraftFieldLayout.minHeight
    @State private var completedExpanded = false
    @State private var editingEntryId: UUID?
    @State private var editingText = ""
    @State private var dismissMonitor = TodayTodoEditingDismissMonitor()
    @State private var draftFocusRequestToken = 0
    @State private var pendingDraftFocus = false

    var body: some View {
        VStack(alignment: .leading, spacing: TodayTodoSectionLayout.sectionSpacing) {
            header

            if case .error(let message) = store.loadState {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if let mutationError = store.mutationError {
                Text(mutationError)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if store.canMutate {
                todoContentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(height: sectionHeight, alignment: .topLeading)
        .task {
            store.loadAndRollForward()
        }
        .onChange(of: editingEntryId) { entryId in
            if entryId != nil {
                dismissMonitor.start {
                    commitEditingIfNeeded()
                }
            } else {
                dismissMonitor.stop()
                TodayTodoEditingFocus.activeView = nil
            }
        }
        .onDisappear {
            dismissMonitor.stop()
        }
        .onAppear {
            scheduleDraftFocusWithRetries()
        }
        .onChange(of: store.loadState) { _ in
            deliverDraftFocusIfReady()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: MalDazeBroadcastNotifications.deskPetDashboardDidOpen
            )
        ) { _ in
            scheduleDraftFocusWithRetries()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: MalDazeBroadcastNotifications.focusDashboardFromDock
            )
        ) { _ in
            scheduleDraftFocusWithRetries()
        }
    }

    private var todoContentArea: some View {
        TodayTodoContentLayout(
            listRowSpacing: TodayTodoSectionLayout.listRowSpacing,
            draftMinimumHeight: draftFieldHeight,
            todoEntries: { todoEntries },
            draftFieldRow: { draftFieldRow }
        )
    }

    private var draftFieldRow: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "circle")
                .font(.title3)
                .foregroundStyle(Color.primary)
                .accessibilityHidden(true)

            TodayTodoDraftField(
                text: $draft,
                placeholder: "Shift+回车换行，回车添加…",
                onSubmit: submitDraft,
                height: $draftFieldHeight,
                focusRequestToken: draftFocusRequestToken
            )
            .frame(height: draftFieldHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(!store.canMutate)
    }

    @ViewBuilder
    private var todoEntries: some View {
        VStack(alignment: .leading, spacing: TodayTodoSectionLayout.listRowSpacing) {
            if store.incompleteEntries.isEmpty, store.completedEntries.isEmpty {
                Text("随手记今天要做的小事，不会同步到提醒事项。")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            if !store.completedEntries.isEmpty {
                DisclosureGroup(isExpanded: $completedExpanded) {
                    ForEach(store.completedEntries) { entry in
                        row(for: entry, isCompleted: true)
                    }
                } label: {
                    Text("已完成 \(store.completedEntries.count)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(store.incompleteEntries) { entry in
                row(for: entry, isCompleted: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(for entry: TodayTodoEntry, isCompleted: Bool) -> some View {
        TodayTodoRow(
            entry: entry,
            isCompleted: isCompleted,
            isEditing: editingEntryId == entry.id,
            editingText: $editingText,
            isBusy: false,
            onToggleComplete: {
                commitEditingIfNeeded()
                store.toggleComplete(id: entry.id)
            },
            onBeginEdit: {
                beginEditing(entry)
            },
            onCommitEdit: {
                commitEditing(entryId: entry.id)
            },
            onDelete: {
                if editingEntryId == entry.id {
                    editingEntryId = nil
                    editingText = ""
                }
                store.delete(id: entry.id)
            }
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("今日 todo")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if store.canMutate {
                Button("历史") {
                    commitEditingIfNeeded()
                    showHistory = true
                }
                .controlSize(.small)
            }
            if !store.incompleteEntries.isEmpty {
                Text("\(store.incompleteEntries.count) 条")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func beginEditing(_ entry: TodayTodoEntry) {
        if editingEntryId != entry.id {
            commitEditingIfNeeded()
            editingEntryId = entry.id
            editingText = entry.title
        }
    }

    private func commitEditing(entryId: UUID) {
        guard editingEntryId == entryId else { return }
        store.updateTitle(id: entryId, title: editingText)
        editingEntryId = nil
        editingText = ""
        TodayTodoEditingFocus.activeView = nil
    }

    private func commitEditingIfNeeded() {
        guard let entryId = editingEntryId else { return }
        commitEditing(entryId: entryId)
    }

    private func submitDraft() -> Bool {
        commitEditingIfNeeded()
        guard store.add(title: draft) else { return false }
        draft = ""
        draftFieldHeight = TodayTodoDraftFieldLayout.minHeight
        return true
    }

    private func scheduleDraftFocusWithRetries() {
        pendingDraftFocus = true
        deliverDraftFocusIfReady()
        for delay in [0.12, 0.28, 0.48, 0.72] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                deliverDraftFocusIfReady()
            }
        }
    }

    private func deliverDraftFocusIfReady() {
        guard store.canMutate else { return }
        pendingDraftFocus = false
        draftFocusRequestToken += 1
    }
}
