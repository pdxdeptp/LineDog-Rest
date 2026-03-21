import SwiftUI

/// 控制面板 UI：同时用于 `MenuBarExtra` 与右下角桌宠的 `NSPopover`（`WindowManager`），改此处即可两边同步。
struct MenuBarContentView: View {
    @ObservedObject var viewModel: AppViewModel

    private var deskReminders: DeskRemindersModel { viewModel.deskReminders }

    /// 左侧提醒栏固定宽度，避免与右侧主菜单抢空间。
    private let remindersColumnWidth: CGFloat = 300

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            remindersSidebar
                .frame(width: remindersColumnWidth, alignment: .topLeading)
                .padding(.trailing, 12)

            Divider()

            mainControlsColumn
                .frame(minWidth: 300, alignment: .leading)
                .padding(.leading, 12)
        }
        .padding(12)
        .frame(minWidth: remindersColumnWidth + 24 + 300 + 24, minHeight: 520)
        .task {
            await deskReminders.prepare()
        }
    }

    /// 左栏：仅提醒事项（系统 EventKit）。
    private var remindersSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提醒事项")
                .font(.headline)
            Text("来自系统「提醒事项」· 所选列表 · 今日未完成 · 不可在此新建")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

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

            Group {
                if deskReminders.isAuthorized {
                    if deskReminders.items.isEmpty {
                        Text("今日无未完成项")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(deskReminders.items) { item in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(item.title.isEmpty ? "（无标题）" : item.title)
                                            .font(.subheadline)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Button("完成") {
                                            Task { await deskReminders.completeReminder(id: item.id) }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                    .padding(.vertical, 4)
                                    Divider()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    Button("连接提醒事项…") {
                        Task { await deskReminders.prepare() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    /// 右栏：番茄钟、小猫、7 分钟提醒等原有控制。
    private var mainControlsColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LineDog Rest")
                .font(.headline)
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

            Toggle(isOn: Binding(
                get: { viewModel.restBlocksClicksDuringRest },
                set: { viewModel.setRestBlocksClicksDuringRest($0) }
            )) {
                Text("休息期间阻止点击桌面")
            }
            .help("打开时休息全屏会挡住背后窗口的鼠标操作（默认）；关闭时休息画面仍在，但可正常使用桌面。")

            Divider()

            Text("独立 7 分钟提醒")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("与线条小狗分层显示；倒计时在屏幕右下角，结束后中心出现铃铛，点一下关闭。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            Button("开始 7 分钟倒计时") {
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

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func restBlockingHint(_ blocks: Bool) -> String {
        if blocks {
            return "休息霸屏期间无关闭按钮；若要终止请使用下方「退出应用」。"
        }
        return "已关闭阻止点击：休息时可正常使用其他窗口；终止休息仍请用菜单或「退出应用」。"
    }
}
