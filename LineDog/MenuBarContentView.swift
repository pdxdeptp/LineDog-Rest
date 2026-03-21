import SwiftUI

/// 控制面板 UI：同时用于 `MenuBarExtra` 与右下角桌宠的 `NSPopover`（`WindowManager`），改此处即可两边同步。
struct MenuBarContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
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

            Text(restBlockingHint(viewModel.restBlocksClicksDuringRest))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button("退出应用…") {
                viewModel.quitApp()
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .padding(12)
        .frame(minWidth: 300)
    }

    private func restBlockingHint(_ blocks: Bool) -> String {
        if blocks {
            return "休息霸屏期间无关闭按钮；若要终止请使用下方「退出应用」。"
        }
        return "已关闭阻止点击：休息时可正常使用其他窗口；终止休息仍请用菜单或「退出应用」。"
    }
}
