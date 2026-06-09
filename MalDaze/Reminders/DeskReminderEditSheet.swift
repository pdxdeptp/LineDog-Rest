import SwiftUI

/// 从「计划」侧栏编辑单条系统提醒：标题、备注、`#日常`、截止日与是否含时刻。
struct DeskReminderEditSheet: View {
    let item: ReminderDisplayItem
    @ObservedObject var deskReminders: DeskRemindersModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ReminderEditDetail(
        calendarItemIdentifier: "",
        title: "",
        notesPlain: "",
        isRoutine: false,
        dueDate: nil,
        includesTimeInDueDate: false
    )
    @State private var loadError: String?
    @State private var isSaving = false
    @State private var didLoad = false

    private let calendar = ScrollMonthDatePickerLogic.pickerCalendar()

    var body: some View {
        NavigationStack {
            Group {
                if let err = loadError {
                    Text(err)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if didLoad {
                    Form {
                        TextField("标题", text: $draft.title)
                        Section("备注") {
                            TextEditor(text: $draft.notesPlain)
                                .frame(minHeight: 88)
                        }
                        Toggle("标记为日常（#日常）", isOn: $draft.isRoutine)
                        Section("截止日期") {
                            Toggle("无截止日期", isOn: Binding(
                                get: { draft.dueDate == nil },
                                set: { noDue in
                                    if noDue {
                                        draft.dueDate = nil
                                    } else {
                                        draft.dueDate = draft.dueDate ?? Calendar.current.startOfDay(for: Date())
                                    }
                                }
                            ))
                            if draft.dueDate != nil {
                                ScrollMonthDatePicker(
                                    selection: dueDateBinding,
                                    accessibilityLabel: "截止日期"
                                )
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                if draft.includesTimeInDueDate {
                                    DatePicker(
                                        "时刻",
                                        selection: dueTimeBinding,
                                        displayedComponents: .hourAndMinute
                                    )
                                }
                                Toggle("指定具体时刻", isOn: $draft.includesTimeInDueDate)
                            }
                        }
                        if let err = deskReminders.mutationMessage, !err.isEmpty {
                            Section {
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .navigationTitle("编辑提醒")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        deskReminders.clearMutationMessage()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .disabled(!didLoad || loadError != nil || isSaving)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 480)
        .task(id: item.id) {
            await load()
        }
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { draft.dueDate ?? Date() },
            set: { newDate in
                guard let current = draft.dueDate else {
                    draft.dueDate = ScrollMonthDatePickerLogic.normalizedSelection(newDate, calendar: calendar)
                    return
                }
                if draft.includesTimeInDueDate {
                    draft.dueDate = ScrollMonthDatePickerLogic.mergeCalendarDay(
                        from: newDate,
                        preservingTimeFrom: current,
                        calendar: calendar
                    )
                } else {
                    draft.dueDate = ScrollMonthDatePickerLogic.normalizedSelection(newDate, calendar: calendar)
                }
            }
        )
    }

    private var dueTimeBinding: Binding<Date> {
        Binding(
            get: { draft.dueDate ?? Date() },
            set: { newTime in
                guard let current = draft.dueDate else {
                    draft.dueDate = newTime
                    return
                }
                draft.dueDate = ScrollMonthDatePickerLogic.mergeCalendarDay(
                    from: current,
                    preservingTimeFrom: newTime,
                    calendar: calendar
                )
            }
        )
    }

    private func load() async {
        loadError = nil
        didLoad = false
        do {
            draft = try await deskReminders.loadReminderForEdit(id: item.id)
            didLoad = true
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func save() async {
        isSaving = true
        await deskReminders.saveReminderEdit(draft)
        isSaving = false
        if deskReminders.mutationMessage == nil {
            dismiss()
        }
    }
}
