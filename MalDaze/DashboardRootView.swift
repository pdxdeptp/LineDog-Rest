import AppKit
import SwiftUI

private enum DashboardLayout {
    static let remindersColumnWidth: CGFloat = 300
    static let assistantMinimumColumnWidth: CGFloat = 360
    static let controlsColumnWidth: CGFloat = 300
    static let horizontalPadding: CGFloat = 12
    static let dividerWidth: CGFloat = 1
    static let safeHorizontalMargin: CGFloat = 48
    static let contentHeight: CGFloat = 664
    static let fallbackVisibleFrame = NSRect(x: 0, y: 0, width: 1280, height: 800)

    static var minimumContentWidth: CGFloat {
        remindersColumnWidth
        + assistantMinimumColumnWidth
        + controlsColumnWidth
        + 2 * horizontalPadding
        + 2 * horizontalPadding
        + 2 * dividerWidth
    }

    static func preferredContentSize(screenVisibleFrame visibleFrame: NSRect?) -> NSSize {
        let visibleFrame = visibleFrame ?? fallbackVisibleFrame
        let targetWidth = visibleFrame.width - 2 * safeHorizontalMargin
        let clampedTargetWidth = min(targetWidth, visibleFrame.width)
        let width = min(max(minimumContentWidth, clampedTargetWidth), visibleFrame.width)
        return NSSize(width: width, height: contentHeight)
    }
}

extension DashboardRootView {
    static var dashboardPreferredContentSize: NSSize {
        DashboardLayout.preferredContentSize(screenVisibleFrame: NSScreen.main?.visibleFrame)
    }
}

/// 桌宠 Dashboard Panel 的语义 root；拥有桌宠入口的窗口级外观与长期状态。
struct DeskPetDashboardView: View {
    private enum DashboardPanelSurface {
        static let cornerRadius: CGFloat = 14
        static let fillOpacity = 0.94
        static let borderOpacity = 0.36

        static func shape() -> RoundedRectangle {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        }
    }

    @ObservedObject var viewModel: AppViewModel
    @StateObject private var learningAssistantViewModel: LearningAssistantViewModel

    static func preferredContentSize(screenVisibleFrame visibleFrame: NSRect?) -> NSSize {
        DashboardLayout.preferredContentSize(screenVisibleFrame: visibleFrame)
    }

    @MainActor
    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        _learningAssistantViewModel = StateObject(wrappedValue: LearningAssistantViewModel())
    }

    var body: some View {
        DashboardRootView(viewModel: viewModel, assistantViewModel: learningAssistantViewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                ZStack {
                    DashboardPanelSurface.shape()
                        .fill(.regularMaterial)
                    DashboardPanelSurface.shape()
                        .fill(Color(.windowBackgroundColor).opacity(DashboardPanelSurface.fillOpacity))
                }
            }
            .clipShape(DashboardPanelSurface.shape())
            .overlay(
                DashboardPanelSurface.shape()
                    .strokeBorder(Color(.separatorColor).opacity(DashboardPanelSurface.borderOpacity), lineWidth: 0.5)
            )
            .onReceive(NotificationCenter.default.publisher(for: MalDazeBroadcastNotifications.deskPetDashboardDidOpen)) { _ in
                Task { await learningAssistantViewModel.refreshForDashboardOpen() }
            }
    }
}

// MARK: - Card style for section grouping

private struct CardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.label
                .padding(.bottom, 6)
            configuration.content
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color(.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}

/// Dashboard 主内容：三栏看板，由桌宠 Dashboard Panel 展示。
struct DashboardRootView: View {
    @ObservedObject var viewModel: AppViewModel
    private let assistantViewModel: LearningAssistantViewModel?

    @AppStorage(MalDazeDefaults.sevenMinuteReminderDurationMinutes) private var sevenMinuteMinutesStored = 7
    @AppStorage(MalDazeDefaults.hydrationReminderIntervalMinutes) private var hydrationIntervalStored = 90
    @AppStorage(MalDazeDefaults.hydrationQuietHoursEnabled) private var hydrationQuietHoursEnabled = false
    @AppStorage(MalDazeDefaults.hydrationQuietStartMinutes) private var hydrationQuietStartMinutes = 1260
    @AppStorage(MalDazeDefaults.hydrationQuietResumeMinutes) private var hydrationQuietResumeMinutes = 480

    @AppStorage(MalDazeDefaults.resetIdlePetShortcutKeyCode) private var resetPetKeyCode: Int = Int(ResetIdlePetPositionShortcut.defaultKeyCode)
    @AppStorage(MalDazeDefaults.resetIdlePetShortcutModifiers) private var resetPetModifiersRaw: Int = ResetIdlePetPositionShortcut.defaultModifiersStorageInt
    @AppStorage(MalDazeDefaults.resetIdlePetShortcutKeyLabel) private var resetPetKeyLabel: String = ResetIdlePetPositionShortcut.default.keyLabel

    @AppStorage(MalDazeDefaults.pomodoroWorkDurationMinutes) private var pomodoroWorkMinutesStored = 25
    @AppStorage(MalDazeDefaults.pomodoroRestDurationMinutes) private var pomodoroRestMinutesStored = 5

    @AppStorage(MalDazeDefaults.idlePetAnimationIntensity) private var idlePetAnimationIntensityStored = 1.0
    @AppStorage(MalDazeDefaults.idlePetIconSidePoints) private var idlePetIconSideStored = MalDazeDefaults.idlePetIconSideDefault

    private var deskReminders: DeskRemindersModel { viewModel.deskReminders }

    @State private var reminderUnderEdit: ReminderDisplayItem?
    @State private var deleteConfirmationId: String?
    /// 拖动中预览；松手后写入 `@AppStorage` 并发帖，避免拖动每一帧写偏好。
    @State private var idlePetIconSideSliderLive = Double(MalDazeDefaults.idlePetIconSideDefault)

    init(viewModel: AppViewModel, assistantViewModel: LearningAssistantViewModel? = nil) {
        self.viewModel = viewModel
        self.assistantViewModel = assistantViewModel
    }

    private var sevenMinuteMinutesResolved: Int {
        let v = sevenMinuteMinutesStored
        if v < 1 { return 7 }
        return min(180, v)
    }

    private var hydrationIntervalResolved: Int {
        let v = hydrationIntervalStored
        if v < 15 { return 90 }
        return min(240, v)
    }

    private var pomodoroWorkMinutesResolved: Int {
        let v = pomodoroWorkMinutesStored
        if v < 5 { return 25 }
        return min(120, v)
    }

    private var pomodoroRestMinutesResolved: Int {
        let v = pomodoroRestMinutesStored
        if v < 1 { return 5 }
        return min(60, v)
    }

    // MARK: - Quiet hours date helpers

    private func minutesToDate(_ totalMinutes: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour   = totalMinutes / 60
        comps.minute = totalMinutes % 60
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func dateToMinutes(_ date: Date) -> Int {
        let cal = Calendar.current
        return cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
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

    /// 推迟到 RunLoop 下一拍，避免 `Picker` / `Toggle` / `onChange` 在视图更新周期内同步调用 `AppViewModel` 触发
    /// 「Publishing changes from within view updates」，并可能导致 `MenuBarExtra` 控制窗被系统收起。
    private func scheduleViewModelWork(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }

    /// 三栏外圈与右栏标题行：数值集中，避免「窗体顶边 vs 首行」只靠右栏独自撑开。
    private enum MainPanelChrome {
        static let horizontalPadding = DashboardLayout.horizontalPadding
        /// 整块内容上内边距。顶部留白唯一控制点，改此处即可（不要在 ScrollView 上加 ignoresSafeArea，否则会被抵消）。
        static let topPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 12
    }

    /// 右栏「MalDaze Rest + 设置」：与下方表单解耦；上下留白只描述本行，不重复承担整块顶距。
    private enum MainPanelHeaderLayout {
        static let rowMinHeight: CGFloat = 44
        static let paddingTop: CGFloat = 4
        static let paddingBottom: CGFloat = 8
        static let gearTapSide: CGFloat = 36
    }

    /// 仅作用于下方 `Toggle` + `.switch` 的打开态轨道色；不改 segmented、普通按钮的 tint。
    private enum SwitchOnTrackTint {
        static let paleBlue = Color(red: 0.45, green: 0.72, blue: 0.98)
    }

    /// 无极拖动得到的 pt → 最近 **4 pt** 刻度，再走 `clampedIdlePetIconSidePoints`（与旧 Stepper 存储语义一致）。
    private static func quantizedIdlePetIconSidePoints(fromContinuousPt continuous: Double) -> Int {
        let lo = Double(MalDazeDefaults.idlePetIconSideMin)
        let hi = Double(MalDazeDefaults.idlePetIconSideMax)
        let bounded = min(max(continuous, lo), hi)
        let snapped = (bounded / 4.0).rounded() * 4.0
        return MalDazeDefaults.clampedIdlePetIconSidePoints(stored: Int(snapped.rounded()))
    }

    var body: some View {
        let chrome = VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // 左栏：提醒事项
                remindersSidebar
                    .frame(width: DashboardLayout.remindersColumnWidth, alignment: .topLeading)
                    .padding(.trailing, MainPanelChrome.horizontalPadding)

                Divider()

                // 中栏：学习助手
                VStack(alignment: .leading, spacing: 0) {
                    if let assistantViewModel {
                        AssistantPanelView(viewModel: assistantViewModel)
                    } else {
                        AssistantPanelView()
                    }
                }
                .frame(minWidth: DashboardLayout.assistantMinimumColumnWidth, maxWidth: .infinity, alignment: .topLeading)

                Divider()

                // 右栏：番茄钟、小猫等原有控制
                mainControlsColumn
                    .frame(width: DashboardLayout.controlsColumnWidth, alignment: .leading)
                    .padding(.leading, MainPanelChrome.horizontalPadding)
            }
            .padding(.horizontal, MainPanelChrome.horizontalPadding)
            .padding(.top, MainPanelChrome.topPadding)
            .padding(.bottom, MainPanelChrome.bottomPadding)
        }
        .frame(
            minWidth: DashboardLayout.minimumContentWidth,
            maxWidth: .infinity,
            minHeight: DashboardLayout.contentHeight
        )

        chrome
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

    private func openMalDazeSettingsWindow() {
        MalDazeSettingsWindowPresenter.present()
    }

    /// 与下方 `statusLine`、表单等解耦：只负责本行在右栏内的垂直居中与留白。
    private var mainPanelHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("MalDaze Rest")
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 12)
            Button {
                openMalDazeSettingsWindow()
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
                    Text(MalDazeRoutineTag.marker)
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
            Text("所选列表 · 今日「#日常」· 未来三个月 · 按日期分组 · 可编辑 / 推迟 / 删除；新建请用智能输入。")
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
                        guard !id.isEmpty else { return }
                        scheduleViewModelWork {
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
                    Text("无逾期待办，未来三个月内也无待办")
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
            VStack(alignment: .leading, spacing: 10) {
                mainPanelHeader

                statusChip

                timerSection

                countdownSection

                hydrationSection

                catSection

                Divider()
                    .padding(.top, 2)

                Text(restBlockingHint(viewModel.restBlocksClicksDuringRest))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("退出应用…") {
                    viewModel.quitApp()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("q", modifiers: [.command])
            }
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: – Status chip

    private var isResting: Bool { viewModel.petDisplayMode == .restingRed }

    private var statusChip: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(isResting ? Color.orange : Color.green)
                .frame(width: 8, height: 8)
            Text(viewModel.statusLine)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isResting ? Color.orange : Color.green)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isResting ? Color.orange : Color.green).opacity(0.10),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    // MARK: – Timer section

    private var timerSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Picker("模式", selection: Binding(
                    get: { viewModel.mode },
                    set: { newMode in
                        scheduleViewModelWork { viewModel.setMode(newMode) }
                    }
                )) {
                    ForEach(AppViewModel.Mode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(value: $pomodoroRestMinutesStored, in: 1...60, step: 1) {
                    Text("休息时长：\(pomodoroRestMinutesResolved) 分钟")
                        .font(.subheadline)
                }
                .help("手动番茄与「整点 / 半点」模式下的休息段长度；霸屏 / 跑屏与计时器一致。")

                Stepper(value: $pomodoroWorkMinutesStored, in: 5...120, step: 1) {
                    Text("专注间隔（仅手动）：\(pomodoroWorkMinutesResolved) 分钟")
                        .font(.subheadline)
                }
                .disabled(viewModel.mode != .manual)
                .help("仅「手动番茄」下每段专注长度；整点模式仍按系统时钟对齐，不受此项影响。")

                HStack(spacing: 8) {
                    Button("开始专注（\(pomodoroWorkMinutesResolved) 分钟）") {
                        viewModel.startManualFocus()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.mode != .manual)
                    .keyboardShortcut("s", modifiers: [.command])

                    if viewModel.showResumeChronoButton {
                        Button("恢复计时") {
                            viewModel.resumeTimers()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("停止计时") {
                            viewModel.stopTimers()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!viewModel.canStopChronoButton)
                    }
                }

                Divider()

                Toggle(isOn: Binding(
                    get: { viewModel.restBlocksClicksDuringRest },
                    set: { v in scheduleViewModelWork { viewModel.setRestBlocksClicksDuringRest(v) } }
                )) {
                    Text("休息期间阻止点击桌面")
                        .font(.subheadline)
                }
                .toggleStyle(.switch)
                .tint(SwitchOnTrackTint.paleBlue)
                .help("打开时休息全屏会挡住背后窗口的鼠标操作（默认）；关闭时休息画面仍在，但可正常使用桌面。")

                Toggle(isOn: Binding(
                    get: { viewModel.restDoubleClickEndsRest },
                    set: { v in scheduleViewModelWork { viewModel.setRestDoubleClickEndsRest(v) } }
                )) {
                    Text("单击 20 下桌宠可提前结束休息")
                        .font(.subheadline)
                }
                .toggleStyle(.switch)
                .tint(SwitchOnTrackTint.paleBlue)
                .help("开启时休息霸屏期间连续单击屏幕中央小狗 20 下（每次间隔 ≤ 3 秒）即可提前结束休息（默认）；关闭后点击无效，只能等计时自然结束。")

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("桌宠图标边长")
                            .font(.subheadline)
                        HStack(spacing: 10) {
                            Text("小")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 14, alignment: .leading)
                            Slider(
                                value: $idlePetIconSideSliderLive,
                                in: Double(MalDazeDefaults.idlePetIconSideMin)...Double(MalDazeDefaults.idlePetIconSideMax)
                            ) { editing in
                                guard !editing else { return }
                                let quantized = Self.quantizedIdlePetIconSidePoints(fromContinuousPt: idlePetIconSideSliderLive)
                                idlePetIconSideStored = quantized
                                idlePetIconSideSliderLive = Double(quantized)
                                NotificationCenter.default.post(
                                    name: MalDazeBroadcastNotifications.idlePetIconSidePointsChanged,
                                    object: nil
                                )
                            }
                            Text("大")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 14, alignment: .trailing)
                        }
                    }
                    .help("调大后更清晰，透明窗口与可点击区域会一起变大。")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("桌宠动态强度")
                            .font(.subheadline)
                        HStack(spacing: 10) {
                            Text("静")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 14, alignment: .leading)
                            Slider(value: $idlePetAnimationIntensityStored, in: 0...1) { editing in
                                if !editing {
                                    NotificationCenter.default.post(
                                        name: MalDazeBroadcastNotifications.idlePetAnimationIntensityChanged,
                                        object: nil
                                    )
                                }
                            }
                            Text("满")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 14, alignment: .trailing)
                        }
                    }
                    .help("左端完全静止；右端与原先「开启动画」一致；中间为较慢的逐帧播放。")
                }
                .onAppear {
                    let clamped = MalDazeDefaults.clampedIdlePetIconSidePoints(stored: idlePetIconSideStored)
                    idlePetIconSideSliderLive = Double(clamped)
                }
                .onChange(of: idlePetIconSideStored) { _ in
                    let clamped = MalDazeDefaults.clampedIdlePetIconSidePoints(stored: idlePetIconSideStored)
                    idlePetIconSideSliderLive = Double(clamped)
                }

                Divider()

                Picker("休息风格", selection: Binding(
                    get: { viewModel.breakInterruptStyle },
                    set: { v in scheduleViewModelWork { viewModel.setBreakInterruptStyle(v) } }
                )) {
                    Text("霸屏（强）").tag(AppViewModel.BreakInterruptStyle.fullscreen)
                    Text("跑屏（轻）").tag(AppViewModel.BreakInterruptStyle.breakRun)
                }
                .pickerStyle(.segmented)
                .help("霸屏：休息时全屏渐暗，小狗居中。跑屏：小狗在桌面漫游，不遮挡工作内容（PawPal 风格）。")

                HStack(spacing: 8) {
                    Button("桌宠归位（\(resetPetShortcutDisplay)）") {
                        viewModel.resetIdlePetPositionFromUserAction()
                    }
                    .buttonStyle(.bordered)
                    .help("将小狗窗口移回菜单栏所在屏可见区右下角并保存；休息霸屏时无效。快捷键可在设置中修改。")

                    Button("立即休息（测试）") {
                        viewModel.startTestRestNow()
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            }
            .onChange(of: pomodoroRestMinutesStored) { _ in
                scheduleViewModelWork { viewModel.syncPomodoroDurationsFromDefaults() }
            }
            .onChange(of: pomodoroWorkMinutesStored) { _ in
                scheduleViewModelWork { viewModel.syncPomodoroDurationsFromDefaults() }
            }
        } label: {
            Label("专注计时", systemImage: "timer")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .textCase(nil)
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    // MARK: – Countdown section

    private var countdownSection: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Stepper(value: $sevenMinuteMinutesStored, in: 1...180) {
                        Text("时长：\(sevenMinuteMinutesResolved) 分钟")
                            .font(.subheadline)
                    }
                    .disabled(viewModel.isSevenMinuteReminderRunning)

                    HStack(spacing: 8) {
                        Button("开始 \(sevenMinuteMinutesResolved) 分钟倒计时") {
                            viewModel.startSevenMinuteReminder()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isSevenMinuteReminderRunning)

                        if viewModel.isSevenMinuteReminderRunning {
                            Button("取消") {
                                viewModel.cancelSevenMinuteReminder()
                            }
                            .buttonStyle(.bordered)
                            .tint(.secondary)
                        }
                    }
                }

                Text("倒计时显示在右下角，结束后铃铛居中提示，点一下关闭。快捷键默认 ⌘⇧M，可在设置里改。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 100, alignment: .leading)
            }
        } label: {
            Label("倒计时提醒", systemImage: "bell")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .textCase(nil)
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    // MARK: – Hydration section

    private var hydrationSection: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: Binding(
                        get: { viewModel.isHydrationReminderEnabled },
                        set: { v in scheduleViewModelWork { viewModel.setHydrationReminderEnabled(v) } }
                    )) {
                        Text("开启喝水提醒")
                            .font(.subheadline)
                    }
                    .toggleStyle(.switch)
                    .tint(SwitchOnTrackTint.paleBlue)

                    Stepper(
                        value: $hydrationIntervalStored,
                        in: 15...240,
                        step: 15,
                        onEditingChanged: { editing in
                            if !editing {
                                scheduleViewModelWork { viewModel.setHydrationReminderInterval(hydrationIntervalStored) }
                            }
                        }
                    ) {
                        Text("间隔：\(hydrationIntervalResolved) 分钟")
                            .font(.subheadline)
                    }
                    .disabled(!viewModel.isHydrationReminderEnabled)

                    Divider()

                    Toggle(isOn: $hydrationQuietHoursEnabled) {
                        Text("开启安静时段")
                            .font(.subheadline)
                    }
                    .toggleStyle(.switch)
                    .tint(SwitchOnTrackTint.paleBlue)
                    .disabled(!viewModel.isHydrationReminderEnabled)

                    HStack(spacing: 6) {
                        Text("停止")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { minutesToDate(hydrationQuietStartMinutes) },
                                set: { hydrationQuietStartMinutes = dateToMinutes($0) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                    .disabled(!viewModel.isHydrationReminderEnabled || !hydrationQuietHoursEnabled)

                    HStack(spacing: 6) {
                        Text("恢复")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { minutesToDate(hydrationQuietResumeMinutes) },
                                set: { hydrationQuietResumeMinutes = dateToMinutes($0) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                    .disabled(!viewModel.isHydrationReminderEnabled || !hydrationQuietHoursEnabled)

                    Button("立即触发（测试）") {
                        viewModel.testFireHydrationReminder()
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("弹出提醒后：「已喝水 💧」重新开始计时，「稍后提醒」15 分钟后再次提醒。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("安静时段内计时器照常运行，到点静默跳过，并在恢复时间后自动弹出下一次提醒。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 100, alignment: .leading)
            }
        } label: {
            Label("喝水提醒", systemImage: "drop.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .textCase(nil)
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    // MARK: – Cat companion section

    private var catSection: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 8) {
                    Button("召唤小猫") {
                        viewModel.startFiveMinuteCatCompanion()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isFiveMinuteCatCompanionActive)

                    if viewModel.isFiveMinuteCatCompanionActive {
                        Button("提前关掉") {
                            viewModel.cancelFiveMinuteCatCompanion()
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                    }
                }

                Text("与线条小狗分层显示；小猫出现在小狗左侧（贴边时改到右侧），5 分钟后渐隐消失。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 100, alignment: .leading)
            }
        } label: {
            Label("5 分钟小猫", systemImage: "pawprint.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .textCase(nil)
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private func restBlockingHint(_ blocks: Bool) -> String {
        if blocks {
            return "休息霸屏无关闭按钮；小狗从角标移到屏幕中央的全过程都可双击它提前结束休息，或使用下方「退出应用」。"
        }
        return "已关闭阻止点击：背后窗口可点；小狗区域仍会接住鼠标，同样可在移动中或居中后双击小狗结束休息。"
    }
}
