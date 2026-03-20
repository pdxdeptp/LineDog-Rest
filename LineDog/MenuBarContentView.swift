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

            Divider()

            Text("休息霸屏期间无关闭按钮；若要终止请使用下方「退出应用」。")
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
}
