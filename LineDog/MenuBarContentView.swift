import AppKit
import SwiftUI

/// 控制面板 UI：同时用于 `MenuBarExtra` 与右下角桌宠的 `NSPopover`（`WindowManager`），改此处即可两边同步。
struct MenuBarContentView: View {
    @ObservedObject var viewModel: AppViewModel

    @AppStorage(LineDogDefaults.sevenMinuteReminderDurationMinutes) private var sevenMinuteMinutesStored = 7

    @AppStorage(LineDogDefaults.resetIdlePetShortcutKeyCode) private var resetPetKeyCode: Int = Int(ResetIdlePetPositionShortcut.defaultKeyCode)
    @AppStorage(LineDogDefaults.resetIdlePetShortcutModifiers) private var resetPetModifiersRaw: Int = ResetIdlePetPositionShortcut.defaultModifiersStorageInt
    @AppStorage(LineDogDefaults.resetIdlePetShortcutKeyLabel) private var resetPetKeyLabel: String = ResetIdlePetPositionShortcut.default.keyLabel

    private var deskReminders: DeskRemindersModel { viewModel.deskReminders }

    @State private var reminderUnderEdit: ReminderDisplayItem?
    @State private var deleteConfirmationId: String?

    private var sevenMinuteMinutesResolved: Int {
        let v = sevenMinuteMinutesStored
        if v < 1 { return 7 }
        return min(180, v)
    }

    private var resetPetShortcutDisplay: String {
        ResetIdlePetPositionShortcut(
            keyCode: UInt16(clamping: resetPetKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(clamping: max(0, resetPetModifiersRaw))),
            keyLabel: resetPetKeyLabel
        ).displayString
    }

    private var reminderDaySections: [DeskReminderDaySection] {
        DeskReminderDayGroups.sections(items: deskReminders.items)
    }

    /// 左侧提醒栏固定宽度，避免与右侧主菜单抢空间。
    private let remindersColumnWidth: CGFloat = 300

    /// 双栏外圈与右栏标题行：数值集中，避免「窗体顶边 vs 首行」只靠右栏独自撑开。
    private enum MainPanelChrome {
        static let horizontalPadding: CGFloat = 12
        /// 整块内容上内边距。顶部留白唯一控制点，改此处即可（不要在 ScrollView 上加 ignoresSafeArea，否则会被抵消）。
        static let topPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 12
    }

    /// 右栏「LineDog Rest + 设置」：与下方表单解耦；上下留白只描述本行，不重复承担整块顶距。
    private enum MainPanelHeaderLayout {
        static let rowMinHeight: CGFloat = 44
        static let paddingTop: CGFloat = 4
        static let paddingBottom: CGFloat = 8
        static let gearTapSide: CGFloat = 36
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                remindersSidebar
                    .frame(width: remindersColumnWidth, alignment: .topLeading)
                    .padding(.trailing, MainPanelChrome.horizontalPadding)

                Divider()

                mainControlsColumn
                    .frame(minWidth: 300, alignment: .leading)
                    .padding(.leading, MainPanelChrome.horizontalPadding)
            }
            .padding(.horizontal, MainPanelChrome.horizontalPadding)
            .padding(.top, MainPanelChrome.topPadding)
            .padding(.bottom, MainPanelChrome.bottomPadding)
        }
        .frame(minWidth: remindersColumnWidth + 24 + 300 + 24, minHeight: 556)
        .sheet(item: $reminderUnderEdit) { item in
            DeskReminderEditSheet(item: item, deskReminders: deskReminders)
        }
        .confirmationDialog(
            "确认删除这条提醒？",
            isPresented: Binding(
                get: { deleteConfirmationId != nil },
                set: { if !$0 { deleteConfirmationId = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let id = deleteConfirmationId {
                    Task { await deskReminders.deleteReminder(id: id) }
                }
                deleteConfirmationId = nil
            }
            Button("取消", role: .cancel) {
                deleteConfirmationId = nil
            }
        } message: {
            Text("将从系统「提醒事项」中移除。")
        }
        .task {
            await deskReminders.prepare()
        }
    }

    private func openLineDogSettingsWindow() {
        LineDogSettingsWindowPresenter.present()
    }

    /// 与下方 `statusLine`、表单等解耦：只负责本行在右栏内的垂直居中与留白。
    private var mainPanelHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("LineDog Rest")
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 12)
            Button {
                openLineDogSettingsWindow()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.headline)
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("设置…")
            .frame(width: MainPanelHeaderLayout.gearTapSide, height: MainPanelHeaderLayout.gearTapSide)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, minHeight: MainPanelHeaderLayout.rowMinHeight, alignment: .center)
        .padding(.top, MainPanelHeaderLayout.paddingTop)
        .padding(.bottom, MainPanelHeaderLayout.paddingBottom)
    }

    @ViewBuilder
    private func deskReminderRow(_ item: ReminderDisplayItem) -> some View {
        let timeText = DeskReminderTimeFormatter.timeOnly(dueDate: item.dueDate, hasExplicitTime: item.hasExplicitTime)
        HStack(alignment: .center, spacing: 10) {
            Button {
                Task { await deskReminders.completeReminder(id: item.id) }
            } label: {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("完成")

            Text(item.title.isEmpty ? "（无标题）" : item.title)
                .font(.body)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                if item.hasRoutineTag {
                    Text(LineDogRoutineTag.marker)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(timeText)
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: timeText == "全天" ? 28 : 36, alignment: .trailing)

                Menu {
                    Button("编辑…") {
                        deskReminders.clearMutationMessage()
                        reminderUnderEdit = item
                    }
                    Button("推迟到明天") {
                        Task { await deskReminders.postponeReminderToTomorrow(id: item.id) }
                    }
                    Button("推迟 7 天") {
                        Task { await deskReminders.postponeReminder(id: item.id, addingDays: 7) }
                    }
                    Divider()
                    Button("删除…", role: .destructive) {
                        deleteConfirmationId = item.id
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("更多")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .contextMenu {
            Button("编辑…") {
                deskReminders.clearMutationMessage()
                reminderUnderEdit = item
            }
            Button("推迟到明天") {
                Task { await deskReminders.postponeReminderToTomorrow(id: item.id) }
            }
            Button("推迟 7 天") {
                Task { await deskReminders.postponeReminder(id: item.id, addingDays: 7) }
            }
            Divider()
            Button("删除…", role: .destructive) {
                deleteConfirmationId = item.id
            }
        }
        Divider()
    }

    /// 左栏：仅提醒事项（系统 EventKit），按日分组类似系统「计划」。
    private var remindersSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("计划")
                .font(.title2.bold())
                .foregroundStyle(.red)
            Text("所选列表 · 今日「#日常」· 七日内 · 按日期分组 · 可编辑 / 推迟 / 删除；新建请用智能输入。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            if let mut = deskReminders.mutationMessage, !mut.isEmpty {
                Text(mut)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let msg = deskReminders.statusMessage, !deskReminders.isAuthorized {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if deskReminders.isAuthorized, !deskReminders.reminderLists.isEmpty {
                Text("同步列表")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("同步列表", selection: Binding(
                    get: { deskReminders.selectedListIdentifier() ?? "" },
                    set: { id in
                        if !id.isEmpty {
                            deskReminders.selectList(calendarIdentifier: id)
                        }
                    }
                )) {
                    ForEach(deskReminders.reminderLists) { list in
                        Text(list.title).tag(list.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            if deskReminders.isAuthorized {
                if deskReminders.items.isEmpty {
                    Text("当前窗口内无待办")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(reminderDaySections.enumerated()), id: \.element.id) { idx, section in
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(section.headerTitle)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .padding(.top, idx == 0 ? 2 : 12)
                                        .padding(.bottom, 6)
                                    Divider()
                                        .opacity(0.45)
                                    ForEach(section.items) { item in
                                        deskReminderRow(item)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                Button("连接提醒事项…") {
                    Task { await deskReminders.prepare() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// 右栏：番茄钟、小猫、7 分钟提醒等原有控制（内容可滚动，高度由左栏决定）。
    private var mainControlsColumn: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 8) {
            mainPanelHeader

            Text(viewModel.statusLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 280, alignment: .leading)

            Divider()

            Picker("模式", selection: Binding(
                get: { viewModel.mode },
                set: { viewModel.setMode($0) }
            )) {
                ForEach(AppViewModel.Mode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("开始专注（25 分钟）") {
                    viewModel.startManualFocus()
                }
                .disabled(viewModel.mode != .manual)
                .keyboardShortcut("s", modifiers: [.command])
            }

            if viewModel.showResumeChronoButton {
                Button("恢复计时") {
                    viewModel.resumeTimers()
                }
            } else {
                Button("停止计时") {
                    viewModel.stopTimers()
                }
                .disabled(!viewModel.canStopChronoButton)
            }

            Button("立即开始休息（测试）") {
                viewModel.startTestRestNow()
            }

            Button("桌宠回到右下角（\(resetPetShortcutDisplay)）") {
                viewModel.resetIdlePetPositionFromUserAction()
            }
            .help("将小狗窗口移回菜单栏所在屏可见区右下角并保存；休息霸屏时无效。快捷键可在设置中修改。")

            Toggle(isOn: Binding(
                get: { viewModel.restBlocksClicksDuringRest },
                set: { viewModel.setRestBlocksClicksDuringRest($0) }
            )) {
                Text("休息期间阻止点击桌面")
            }
            .help("打开时休息全屏会挡住背后窗口的鼠标操作（默认）；关闭时休息画面仍在，但可正常使用桌面。")

            Divider()

            Text("独立倒计时提醒")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Stepper(value: $sevenMinuteMinutesStored, in: 1...180) {
                Text("时长：\(sevenMinuteMinutesResolved) 分钟")
            }
            .disabled(viewModel.isSevenMinuteReminderRunning)
            Text("与线条小狗分层显示；倒计时在屏幕右下角，结束后屏幕中央显示铃铛与说明文字，点一下关闭。全局快捷键可在设置里改（默认 ⌘⇧M，再按取消）。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            Button("开始 \(sevenMinuteMinutesResolved) 分钟倒计时") {
                viewModel.startSevenMinuteReminder()
            }
            .disabled(viewModel.isSevenMinuteReminderRunning)
            if viewModel.isSevenMinuteReminderRunning {
                Button("取消倒计时") {
                    viewModel.cancelSevenMinuteReminder()
                }
            }

            Divider()

            Text("独立 5 分钟小猫")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("与线条小狗分层；小猫跟在小狗左侧（若贴边则改到右侧），5 分钟后渐隐消失。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            Button("出现 5 分钟小猫") {
                viewModel.startFiveMinuteCatCompanion()
            }
            .disabled(viewModel.isFiveMinuteCatCompanionActive)
            if viewModel.isFiveMinuteCatCompanionActive {
                Button("提前关掉小猫") {
                    viewModel.cancelFiveMinuteCatCompanion()
                }
            }

            Divider()

            Text(restBlockingHint(viewModel.restBlocksClicksDuringRest))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button("退出应用…") {
                viewModel.quitApp()
            }
            .keyboardShortcut("q", modifiers: [.command])

        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        } // end ScrollView
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func restBlockingHint(_ blocks: Bool) -> String {
        if blocks {
            return "休息霸屏无关闭按钮；小狗从角标移到屏幕中央的全过程都可双击它提前结束休息，或使用下方「退出应用」。"
        }
        return "已关闭阻止点击：背后窗口可点；小狗区域仍会接住鼠标，同样可在移动中或居中后双击小狗结束休息。"
    }
}
