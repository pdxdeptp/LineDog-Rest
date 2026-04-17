import AppKit
import Combine
import Foundation

/// 应用级协调：模式切换、计时引擎与霸屏窗口的单向数据流。
@MainActor
final class AppViewModel: ObservableObject {
    enum Mode: String, CaseIterable {
        case manual = "手动番茄"
        case auto = "整点 / 半点"
    }

    @Published private(set) var mode: Mode = .auto
    @Published private(set) var statusLine: String = "自动模式：正在对齐系统时钟…"
    /// 状态栏小狗与「休息中」红态；与桌宠非休息配色同步。
    @Published private(set) var petDisplayMode: PetDisplayMode = .runningBlack

    /// 菜单「停止计时」：仅当引擎实际在跑时为可点。
    @Published private(set) var canStopChronoButton = false
    /// 菜单「恢复计时」：用户从运行中点过「停止计时」后为 true，直到恢复或切模式。
    @Published private(set) var showResumeChronoButton = false
    /// 休息全屏时是否拦截鼠标（默认开）；关则休息时仍可正常点击背后桌面与应用。
    @Published private(set) var restBlocksClicksDuringRest: Bool
    /// 独立 7 分钟倒计时进行中（与桌宠无关）；结束后出现铃铛直至点击关闭。
    @Published private(set) var isSevenMinuteReminderRunning = false
    /// 独立 5 分钟小猫陪伴窗口是否正在显示（渐隐结束前为 true）。
    @Published private(set) var isFiveMinuteCatCompanionActive = false

    /// 提醒事项同步（EventKit）；与菜单栏、桌宠 Popover 共用。
    let deskReminders: DeskRemindersModel

    private static let restBlocksClicksDefaultsKey = "LineDog.restBlocksClicksDuringRest"
    private var cancellables = Set<AnyCancellable>()

    /// 「计时中」：自动模式引擎在跑，或手动模式已点「开始专注」尚未「停止计时」。
    private var isChronoSessionActive: Bool
    /// 用户主动暂停后，同一会话内可用「恢复计时」继续（手动：重新一轮工作段；自动：重新对齐锚点）。
    private var chronoSessionSuspendedByUser = false

    private let manualEngine: ManualTimerEngine
    private let autoEngine: AutoTimerEngine
    private let windowManager: WindowManaging
    private let smartReminderOrchestrator: SmartReminderOrchestrator
    /// 独立倒计时提醒窗口，不经过 `WindowManager`。
    private let sevenMinuteReminder: SevenMinuteReminderController
    /// 独立小猫窗口，不经过 `WindowManager`。
    private let fiveMinuteCatCompanion: FiveMinuteCatCompanionController

    private var wasResting = false
    private var testRestActive = false
    private var cachedStatusLine: String = "自动模式：正在对齐系统时钟…"
    /// 避免 `syncPetDisplayMode` 在计时器 tick 中重复调用 `WindowManager`（模式未变时）。
    private var lastIdlePetModeAppliedToWindow: PetDisplayMode?
    /// 智能输入等待 Gemini 时，桌宠与菜单栏显示「思考」态。
    private var smartReminderThinkingActive = false
    private var smartReminderShortcutObserver: NSObjectProtocol?
    private var deskPetMenuShortcutObserver: NSObjectProtocol?
    private var sevenMinuteShortcutObserver: NSObjectProtocol?
    private var resetIdlePetShortcutObserver: NSObjectProtocol?
    /// 智能提醒写入的 `EKAlarm` 到点后弹出与 7 分钟倒计时相同的中央铃铛。
    private var smartReminderBellTasks: [String: Task<Void, Never>] = [:]

    /// - Parameters:
    ///   - bootstrapAutoEngine: 应用启动为 `true` 并立即跑自动模式；单测传 `false` 避免后台 tick。
    init(
        windowManager: WindowManaging = WindowManager(),
        manualEngine: ManualTimerEngine? = nil,
        autoEngine: AutoTimerEngine? = nil,
        bootstrapAutoEngine: Bool = true,
        sevenMinuteReminder: SevenMinuteReminderController? = nil,
        fiveMinuteCatCompanion: FiveMinuteCatCompanionController? = nil,
        deskReminders: DeskRemindersModel? = nil
    ) {
        self.windowManager = windowManager
        self.sevenMinuteReminder = sevenMinuteReminder ?? SevenMinuteReminderController()
        self.fiveMinuteCatCompanion = fiveMinuteCatCompanion ?? FiveMinuteCatCompanionController()
        self.deskReminders = deskReminders ?? DeskRemindersModel()
        self.smartReminderOrchestrator = SmartReminderOrchestrator(
            apiKeyProvider: {
                UserDefaults.standard.string(forKey: LineDogDefaults.geminiAPIKey)
            }
        )
        let me = manualEngine ?? ManualTimerEngine()
        let ae = autoEngine ?? AutoTimerEngine()
        self.manualEngine = me
        self.autoEngine = ae
        self.isChronoSessionActive = bootstrapAutoEngine
        if UserDefaults.standard.object(forKey: Self.restBlocksClicksDefaultsKey) == nil {
            self.restBlocksClicksDuringRest = true
        } else {
            self.restBlocksClicksDuringRest = UserDefaults.standard.bool(forKey: Self.restBlocksClicksDefaultsKey)
        }

        // Timer 回调在主 RunLoop 线程上执行，但不在 MainActor 任务上下文中；
        // 使用 `assumeIsolated` 会触发运行时 trap，导致引擎状态永远进不了 ViewModel（霸屏/变暗/菜单状态失效）。
        me.onStateChange = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleTimeState(state, source: .manual)
            }
        }
        ae.onStateChange = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleTimeState(state, source: .auto)
            }
        }

        if !bootstrapAutoEngine {
            statusLine = "（测试）"
            cachedStatusLine = statusLine
        } else {
            ae.start()
        }
        refreshChronoChrome()
        syncPetDisplayMode()
        windowManager.bindDeskPetMenu(viewModel: self)
        windowManager.setRestBlocksClicks(restBlocksClicksDuringRest)

        self.sevenMinuteReminder.onRunningChanged = { [weak self] running in
            self?.isSevenMinuteReminderRunning = running
        }
        self.fiveMinuteCatCompanion.onActiveChanged = { [weak self] active in
            self?.isFiveMinuteCatCompanionActive = active
        }

        self.deskReminders.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        smartReminderShortcutObserver = NotificationCenter.default.addObserver(
            forName: LineDogBroadcastNotifications.openSmartReminderInput,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.presentSmartReminderFromGlobalShortcut()
        }

        deskPetMenuShortcutObserver = NotificationCenter.default.addObserver(
            forName: LineDogBroadcastNotifications.presentDeskPetMenu,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.presentDeskPetMenuFromGlobalShortcut()
        }

        sevenMinuteShortcutObserver = NotificationCenter.default.addObserver(
            forName: LineDogBroadcastNotifications.toggleSevenMinuteReminder,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.toggleSevenMinuteReminderFromGlobalShortcut()
        }

        resetIdlePetShortcutObserver = NotificationCenter.default.addObserver(
            forName: LineDogBroadcastNotifications.resetIdlePetPositionToDefault,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetIdlePetPositionFromUserAction()
        }
    }

    deinit {
        if let smartReminderShortcutObserver {
            NotificationCenter.default.removeObserver(smartReminderShortcutObserver)
        }
        if let deskPetMenuShortcutObserver {
            NotificationCenter.default.removeObserver(deskPetMenuShortcutObserver)
        }
        if let sevenMinuteShortcutObserver {
            NotificationCenter.default.removeObserver(sevenMinuteShortcutObserver)
        }
        if let resetIdlePetShortcutObserver {
            NotificationCenter.default.removeObserver(resetIdlePetShortcutObserver)
        }
    }

    private func presentDeskPetMenuFromGlobalShortcut() {
        windowManager.presentDeskMenuFromGlobalShortcut()
    }

    /// 桌宠右键：由 `WindowManager` 转屏幕坐标后调用。
    func userRequestedSmartReminderInput(screenAnchor: NSRect) {
        windowManager.presentSmartReminderInput(
            anchorRectInScreen: screenAnchor,
            onSubmit: { [weak self] text in
                guard let self else { return }
                Task { await self.processSmartReminderSubmit(text) }
            },
            onCancel: {}
        )
    }

    func presentSmartReminderFromGlobalShortcut() {
        windowManager.presentSmartReminderInputFromGlobalShortcut(
            onSubmit: { [weak self] text in
                guard let self else { return }
                Task { await self.processSmartReminderSubmit(text) }
            },
            onCancel: {}
        )
    }

    @MainActor
    private func processSmartReminderSubmit(_ raw: String) async {
        smartReminderThinkingActive = true
        syncPetDisplayMode()
        let result = await smartReminderOrchestrator.run(
            rawUserInput: raw,
            uiSelectedReminderListCalendarId: deskReminders.selectedListIdentifier()
        )
        smartReminderThinkingActive = false
        syncPetDisplayMode()
        guard let result else { return }
        let savedOK = !result.undoItemIdentifiers.isEmpty && !result.incompleteMultiSave
        if savedOK {
            windowManager.clearSmartReminderInputDraftIfStillMatchesSubmittedText(raw)
        }
        windowManager.showSmartReminderToast(
            message: result.toastMessage,
            showUndo: !result.undoItemIdentifiers.isEmpty,
            onUndo: { [weak self] in
                guard let self, !result.undoItemIdentifiers.isEmpty else { return }
                Task { await self.performSmartReminderUndo(ids: result.undoItemIdentifiers) }
            },
            onAutoDismiss: {}
        )
        for bell in result.inAppBells {
            scheduleSmartReminderInAppBell(
                itemId: bell.itemIdentifier,
                fireDate: bell.fireDate,
                message: bell.message
            )
        }
    }

    @MainActor
    private func performSmartReminderUndo(ids: [String]) async {
        for id in ids {
            cancelSmartReminderInAppBell(forItemId: id)
        }
        windowManager.applyIdlePetDisplayMode(.pausedWhiteOutline)
        try? await Task.sleep(nanoseconds: 220_000_000)
        for id in ids {
            try? await smartReminderOrchestrator.removeReminder(calendarItemIdentifier: id)
        }
        syncPetDisplayMode()
    }

    private func scheduleSmartReminderInAppBell(itemId: String, fireDate: Date, message: String) {
        cancelSmartReminderInAppBell(forItemId: itemId)
        let delay = fireDate.timeIntervalSinceNow
        if delay <= 0.5 {
            if delay > -300 {
                sevenMinuteReminder.presentCenterBellReminder(message: message)
            }
            return
        }
        smartReminderBellTasks[itemId] = Task { @MainActor [weak self] in
            let ns = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard let self, !Task.isCancelled else { return }
            self.smartReminderBellTasks.removeValue(forKey: itemId)
            self.sevenMinuteReminder.presentCenterBellReminder(message: message)
        }
    }

    private func cancelSmartReminderInAppBell(forItemId itemId: String) {
        smartReminderBellTasks[itemId]?.cancel()
        smartReminderBellTasks.removeValue(forKey: itemId)
    }

    func startFiveMinuteCatCompanion() {
        fiveMinuteCatCompanion.start()
    }

    func cancelFiveMinuteCatCompanion() {
        fiveMinuteCatCompanion.cancel()
    }

    func startSevenMinuteReminder() {
        sevenMinuteReminder.start()
    }

    func cancelSevenMinuteReminder() {
        sevenMinuteReminder.cancel()
    }

    private func toggleSevenMinuteReminderFromGlobalShortcut() {
        if isSevenMinuteReminderRunning {
            cancelSevenMinuteReminder()
        } else {
            startSevenMinuteReminder()
        }
    }

    /// 菜单或全局快捷键：常态桌宠回到菜单栏屏可见区右下角（休息霸屏中由 `WindowManager` 忽略）。
    func resetIdlePetPositionFromUserAction() {
        windowManager.resetIdlePetPositionToDefaultCorner()
    }

    func setRestBlocksClicksDuringRest(_ enabled: Bool) {
        restBlocksClicksDuringRest = enabled
        UserDefaults.standard.set(enabled, forKey: Self.restBlocksClicksDefaultsKey)
        windowManager.setRestBlocksClicks(enabled)
    }

    private enum Source { case manual, auto }

    func setMode(_ newMode: Mode) {
        mode = newMode
        manualEngine.stop()
        autoEngine.stop()
        windowManager.dismissRestImmediately()
        wasResting = false
        testRestActive = false
        chronoSessionSuspendedByUser = false

        switch newMode {
        case .manual:
            isChronoSessionActive = false
            publishStatus("手动模式：点击「开始专注」。")
        case .auto:
            isChronoSessionActive = true
            publishStatus("自动模式：正在对齐系统时钟…")
            autoEngine.start()
        }
        refreshChronoChrome()
        syncPetDisplayMode()
    }

    func startManualFocus() {
        guard mode == .manual else { return }
        autoEngine.stop()
        windowManager.dismissRestImmediately()
        wasResting = false
        testRestActive = false
        chronoSessionSuspendedByUser = false
        manualEngine.start()
        isChronoSessionActive = true
        refreshChronoChrome()
        syncPetDisplayMode()
    }

    /// 暂停当前模式下的计时（手动 / 自动）；未在计时时忽略。之后显示「恢复计时」。
    func stopTimers() {
        guard isChronoSessionActive else { return }
        manualEngine.stop()
        autoEngine.stop()
        windowManager.dismissRestImmediately()
        wasResting = false
        testRestActive = false
        isChronoSessionActive = false
        chronoSessionSuspendedByUser = true
        if mode == .manual {
            publishStatus("已暂停。点击「恢复计时」继续，或再次「开始专注」开新一轮。")
        } else {
            publishStatus("自动提醒已暂停。点击「恢复计时」重新对齐整点 / 半点。")
        }
        refreshChronoChrome()
        syncPetDisplayMode()
    }

    /// 在用户点击「停止计时」之后恢复同一模式下的计时。
    func resumeTimers() {
        guard chronoSessionSuspendedByUser else { return }
        chronoSessionSuspendedByUser = false
        windowManager.dismissRestImmediately()
        wasResting = false
        testRestActive = false

        switch mode {
        case .manual:
            manualEngine.start()
            isChronoSessionActive = true
        case .auto:
            autoEngine.start()
            isChronoSessionActive = true
            publishStatus("自动模式：正在对齐系统时钟…")
        }
        refreshChronoChrome()
        syncPetDisplayMode()
    }

    /// 休息全屏中央小狗**双击**：收起霸屏，并让计时引擎退出当前休息段（测试休息则走与普通结束相同的回调）。
    func endRestEarlyFromDeskPet() {
        if testRestActive {
            windowManager.dismissRestImmediately()
            return
        }
        windowManager.dismissRestImmediately()
        switch mode {
        case .manual:
            if manualEngine.isInRestPhase {
                manualEngine.skipRestPhaseToWork()
            }
        case .auto:
            if autoEngine.isInScheduledRest {
                autoEngine.skipScheduledRest()
            }
        }
        wasResting = false
        syncPetDisplayMode()
    }

    func startTestRestNow() {
        testRestActive = true
        syncPetDisplayMode()
        statusLine = "【测试】休息霸屏中（约 5 分钟）…"
        windowManager.presentRest(duration: 5 * 60) { [weak self] in
            guard let self else { return }
            // 必须在主线程同步执行：`WindowManager` / 单测 Mock 会在同一拍调用此回调，
            // 若再包一层 `Task` 会导致测试与 UI 在霸屏结束瞬间读到陈旧状态。
            self.testRestActive = false
            self.statusLine = self.cachedStatusLine
            self.resumeEngineRestOverlayIfNeeded()
            self.syncPetDisplayMode()
        }
    }

    func quitApp() {
        NSApp.terminate(nil)
    }

    /// 测试休息结束后：若番茄/自动引擎仍在「休息段」内，需重新拉起霸屏（测试期间曾 `dismiss` 掉引擎那一轮）。
    private func resumeEngineRestOverlayIfNeeded() {
        switch mode {
        case .manual:
            if manualEngine.isTimerRunning && manualEngine.isInRestPhase {
                wasResting = true
                windowManager.presentRest(duration: 5 * 60) { }
            } else {
                wasResting = false
            }
        case .auto:
            if autoEngine.isTimerRunning && autoEngine.isInScheduledRest {
                wasResting = true
                windowManager.presentRest(duration: 5 * 60) { }
            } else {
                wasResting = false
            }
        }
    }

    private func handleTimeState(_ state: TimeState, source: Source) {
        switch mode {
        case .manual where source != .manual:
            return
        case .auto where source != .auto:
            return
        default:
            break
        }

        switch state {
        case .idle:
            publishStatus("空闲")
            wasResting = false
        case .working(let remaining):
            wasResting = false
            publishStatus("专注中 · 剩余 \(Self.formatClock(remaining))")
        case .resting(let remaining):
            publishStatus("休息中 · 剩余 \(Self.formatClock(remaining))（请放松双眼）")
            if !wasResting {
                wasResting = true
                if !testRestActive {
                    windowManager.presentRest(duration: 5 * 60) { }
                }
            }
        case .autoWatching(let next):
            wasResting = false
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "HH:mm"
            publishStatus("下次休息 \(f.string(from: next))")
        }
        syncPetDisplayMode()
    }

    private func refreshChronoChrome() {
        canStopChronoButton = isChronoSessionActive
        showResumeChronoButton = chronoSessionSuspendedByUser
    }

    private func syncPetDisplayMode() {
        let menuMode: PetDisplayMode
        if smartReminderThinkingActive {
            menuMode = .thinking
        } else if testRestActive || wasResting {
            menuMode = .restingRed
        } else if isChronoSessionActive {
            menuMode = .runningBlack
        } else {
            menuMode = .pausedWhiteOutline
        }
        if petDisplayMode != menuMode {
            petDisplayMode = menuMode
        }

        let idleMode: PetDisplayMode
        if smartReminderThinkingActive {
            idleMode = .thinking
        } else if isChronoSessionActive {
            idleMode = .runningBlack
        } else {
            idleMode = .pausedWhiteOutline
        }
        if lastIdlePetModeAppliedToWindow != idleMode {
            lastIdlePetModeAppliedToWindow = idleMode
            windowManager.applyIdlePetDisplayMode(idleMode)
        }
    }

    private func publishStatus(_ line: String) {
        cachedStatusLine = line
        if !testRestActive {
            statusLine = line
        }
    }

    private static func formatClock(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval.rounded(.down)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - XCTest（同文件以访问 `private` 的 `handleTimeState`）

extension AppViewModel {
    /// 单测注入引擎状态，不依赖 `Timer`。
    func testing_injectTimeState(_ state: TimeState, fromManualEngine: Bool) {
        handleTimeState(state, source: fromManualEngine ? .manual : .auto)
    }
}
