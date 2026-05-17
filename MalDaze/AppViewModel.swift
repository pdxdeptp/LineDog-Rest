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

    /// 休息打断风格：`fullscreen`（默认霸屏）或 `breakRun`（PawPal 风格跑屏漫游）。
    enum BreakInterruptStyle: String {
        case fullscreen = "fullscreen"
        case breakRun   = "breakRun"
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
    /// 休息霸屏期间连续单击桌宠 20 下可提前结束休息（默认开）。
    @Published private(set) var restDoubleClickEndsRest: Bool
    /// 独立 7 分钟倒计时进行中（与桌宠无关）；结束后出现铃铛直至点击关闭。
    @Published private(set) var isSevenMinuteReminderRunning = false
    /// 独立 5 分钟小猫陪伴窗口是否正在显示（渐隐结束前为 true）。
    @Published private(set) var isFiveMinuteCatCompanionActive = false
    /// 喝水提醒已调度（计时中或浮层待操作）为 true；开关关闭或调用 cancel 后变 false。
    @Published private(set) var isHydrationReminderEnabled: Bool
    /// 休息打断风格，持久化到 UserDefaults。
    @Published private(set) var breakInterruptStyle: BreakInterruptStyle

    /// 提醒事项同步（EventKit）；与菜单栏、桌宠 Dashboard 共用。
    let deskReminders: DeskRemindersModel

    private static let restBlocksClicksDefaultsKey = "MalDaze.restBlocksClicksDuringRest"
    private static let restDoubleClickEndsRestDefaultsKey = MalDazeDefaults.restDoubleClickEndsRest

    /// 与菜单栏 Stepper 一致：5…120 分钟，非法或未写入时默认 25。
    static func clampedPomodoroWorkMinutes(_ stored: Int) -> Int {
        if stored < 5 { return 25 }
        return min(120, stored)
    }

    /// 与菜单栏 Stepper 一致：1…60 分钟，非法或未写入时默认 5。
    static func clampedPomodoroRestMinutes(_ stored: Int) -> Int {
        if stored < 1 { return 5 }
        return min(60, stored)
    }

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
    /// 喝水提醒控制器，不经过 `WindowManager`。
    private let hydrationReminder: HydrationReminderController

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
    private var idlePetIconSidePointsObserver: NSObjectProtocol?
    private var idlePetAnimationIntensityObserver: NSObjectProtocol?
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
        hydrationReminder: HydrationReminderController? = nil,
        deskReminders: DeskRemindersModel? = nil
    ) {
        self.windowManager = windowManager
        self.sevenMinuteReminder = sevenMinuteReminder ?? SevenMinuteReminderController()
        self.fiveMinuteCatCompanion = fiveMinuteCatCompanion ?? FiveMinuteCatCompanionController()
        self.hydrationReminder = hydrationReminder ?? HydrationReminderController()
        self.isHydrationReminderEnabled = UserDefaults.standard.bool(forKey: MalDazeDefaults.hydrationReminderEnabled)
        let rawStyle = UserDefaults.standard.string(forKey: MalDazeDefaults.breakInterruptStyle) ?? ""
        self.breakInterruptStyle = BreakInterruptStyle(rawValue: rawStyle) ?? .fullscreen
        self.deskReminders = deskReminders ?? DeskRemindersModel()
        self.smartReminderOrchestrator = SmartReminderOrchestrator(
            apiKeyProvider: {
                UserDefaults.standard.string(forKey: MalDazeDefaults.geminiAPIKey)
            }
        )
        let ud = UserDefaults.standard
        let wMin = Self.clampedPomodoroWorkMinutes(ud.integer(forKey: MalDazeDefaults.pomodoroWorkDurationMinutes))
        let rMin = Self.clampedPomodoroRestMinutes(ud.integer(forKey: MalDazeDefaults.pomodoroRestDurationMinutes))
        ud.set(wMin, forKey: MalDazeDefaults.pomodoroWorkDurationMinutes)
        ud.set(rMin, forKey: MalDazeDefaults.pomodoroRestDurationMinutes)
        let me = manualEngine ?? ManualTimerEngine(
            workDuration: TimeInterval(wMin * 60),
            restDuration: TimeInterval(rMin * 60)
        )
        let ae = autoEngine ?? AutoTimerEngine(restDuration: TimeInterval(rMin * 60))
        self.manualEngine = me
        self.autoEngine = ae
        self.isChronoSessionActive = bootstrapAutoEngine
        if UserDefaults.standard.object(forKey: Self.restBlocksClicksDefaultsKey) == nil {
            self.restBlocksClicksDuringRest = true
        } else {
            self.restBlocksClicksDuringRest = UserDefaults.standard.bool(forKey: Self.restBlocksClicksDefaultsKey)
        }
        if UserDefaults.standard.object(forKey: Self.restDoubleClickEndsRestDefaultsKey) == nil {
            self.restDoubleClickEndsRest = true
        } else {
            self.restDoubleClickEndsRest = UserDefaults.standard.bool(forKey: Self.restDoubleClickEndsRestDefaultsKey)
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

        self.hydrationReminder.onStateChanged = { [weak self] active in
            self?.isHydrationReminderEnabled = active
        }
        if self.isHydrationReminderEnabled {
            self.hydrationReminder.start()
        }

        self.deskReminders.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        smartReminderShortcutObserver = NotificationCenter.default.addObserver(
            forName: MalDazeBroadcastNotifications.openSmartReminderInput,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.presentSmartReminderFromGlobalShortcut()
        }

        deskPetMenuShortcutObserver = NotificationCenter.default.addObserver(
            forName: MalDazeBroadcastNotifications.presentDeskPetMenu,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.presentDeskPetMenuFromGlobalShortcut()
        }

        sevenMinuteShortcutObserver = NotificationCenter.default.addObserver(
            forName: MalDazeBroadcastNotifications.toggleSevenMinuteReminder,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.toggleSevenMinuteReminderFromGlobalShortcut()
        }

        resetIdlePetShortcutObserver = NotificationCenter.default.addObserver(
            forName: MalDazeBroadcastNotifications.resetIdlePetPositionToDefault,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetIdlePetPositionFromUserAction()
        }

        idlePetIconSidePointsObserver = NotificationCenter.default.addObserver(
            forName: MalDazeBroadcastNotifications.idlePetIconSidePointsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyIdlePetIconSideFromUserDefaults()
        }

        idlePetAnimationIntensityObserver = NotificationCenter.default.addObserver(
            forName: MalDazeBroadcastNotifications.idlePetAnimationIntensityChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyIdlePetAnimationFromUserDefaults()
        }
    }

    /// 从 `UserDefaults` 同步番茄工作/休息时长到两个引擎（面板 Stepper 与设置改动后调用）。
    func syncPomodoroDurationsFromDefaults() {
        let ud = UserDefaults.standard
        let wMin = Self.clampedPomodoroWorkMinutes(ud.integer(forKey: MalDazeDefaults.pomodoroWorkDurationMinutes))
        let rMin = Self.clampedPomodoroRestMinutes(ud.integer(forKey: MalDazeDefaults.pomodoroRestDurationMinutes))
        ud.set(wMin, forKey: MalDazeDefaults.pomodoroWorkDurationMinutes)
        ud.set(rMin, forKey: MalDazeDefaults.pomodoroRestDurationMinutes)
        manualEngine.setPhaseDurations(work: TimeInterval(wMin * 60), rest: TimeInterval(rMin * 60))
        autoEngine.setRestDuration(TimeInterval(rMin * 60))
    }

    private func resolvedRestDurationSecondsFromDefaults() -> TimeInterval {
        TimeInterval(Self.clampedPomodoroRestMinutes(UserDefaults.standard.integer(forKey: MalDazeDefaults.pomodoroRestDurationMinutes)) * 60)
    }

    deinit {
        let h = hydrationReminder
        Task { @MainActor in h.cancel() }
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
        if let idlePetIconSidePointsObserver {
            NotificationCenter.default.removeObserver(idlePetIconSidePointsObserver)
        }
        if let idlePetAnimationIntensityObserver {
            NotificationCenter.default.removeObserver(idlePetAnimationIntensityObserver)
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
        let result = await smartReminderOrchestrator.run(rawUserInput: raw)
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

    func setHydrationReminderEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: MalDazeDefaults.hydrationReminderEnabled)
        isHydrationReminderEnabled = enabled
        if enabled {
            hydrationReminder.start()
        } else {
            hydrationReminder.cancel()
        }
    }

    func setHydrationReminderInterval(_ minutes: Int) {
        let clamped = min(240, max(15, minutes))
        UserDefaults.standard.set(clamped, forKey: MalDazeDefaults.hydrationReminderIntervalMinutes)
        if isHydrationReminderEnabled {
            hydrationReminder.cancel()
            hydrationReminder.start()
        }
    }

    func testFireHydrationReminder() {
        hydrationReminder.testing_fireNow()
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

    /// 桌宠图标边长（UserDefaults）变更后刷新小窗与命中区。
    func applyIdlePetIconSideFromUserDefaults() {
        windowManager.applyIdlePetIconSideFromUserDefaults()
    }

    /// 桌宠 GIF 动态偏好变更后刷新 `PetRenderer`。
    func applyIdlePetAnimationFromUserDefaults() {
        windowManager.applyIdlePetAnimationFromUserDefaults()
    }

    func setRestBlocksClicksDuringRest(_ enabled: Bool) {
        restBlocksClicksDuringRest = enabled
        UserDefaults.standard.set(enabled, forKey: Self.restBlocksClicksDefaultsKey)
        windowManager.setRestBlocksClicks(enabled)
    }

    func setRestDoubleClickEndsRest(_ enabled: Bool) {
        restDoubleClickEndsRest = enabled
        UserDefaults.standard.set(enabled, forKey: Self.restDoubleClickEndsRestDefaultsKey)
    }

    private enum Source { case manual, auto }

    func setMode(_ newMode: Mode) {
        mode = newMode
        manualEngine.stop()
        autoEngine.stop()
        windowManager.dismissRestImmediately(bringIdlePetWindowToFront: false)
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
        windowManager.dismissRestImmediately(bringIdlePetWindowToFront: false)
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
        windowManager.dismissRestImmediately(bringIdlePetWindowToFront: false)
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
        windowManager.dismissRestImmediately(bringIdlePetWindowToFront: false)
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

    /// 休息全屏中央小狗**连续单击 20 下**：收起霸屏，并让计时引擎退出当前休息段（测试休息则走与普通结束相同的回调）。
    /// 若用户在设置中关闭「单击 20 下桌宠结束休息」，本函数直接返回。
    func endRestEarlyFromDeskPet() {
        guard restDoubleClickEndsRest else { return }
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
        let modeLabel = breakInterruptStyle == .breakRun ? "跑屏" : "霸屏"
        let restSec = resolvedRestDurationSecondsFromDefaults()
        let restMin = max(1, Int((restSec / 60).rounded(.down)))
        statusLine = "【测试】休息\(modeLabel)中（约 \(restMin) 分钟）…"
        presentRestWithCurrentStyle(duration: restSec) { [weak self] in
            guard let self else { return }
            // 必须在主线程同步执行：`WindowManager` / 单测 Mock 会在同一拍调用此回调，
            // 若再包一层 `Task` 会导致测试与 UI 在霸屏结束瞬间读到陈旧状态。
            self.testRestActive = false
            self.statusLine = self.cachedStatusLine
            self.resumeEngineRestOverlayIfNeeded()
            self.syncPetDisplayMode()
        }
    }

    /// 根据当前 `breakInterruptStyle` 路由到对应休息入口。
    private func presentRestWithCurrentStyle(duration: TimeInterval, onDismissed: @escaping () -> Void) {
        switch breakInterruptStyle {
        case .fullscreen:
            windowManager.presentRest(duration: duration, onDismissed: onDismissed)
        case .breakRun:
            windowManager.presentBreakRun(duration: duration, onDismissed: onDismissed)
        }
    }

    /// 用户在设置中更改休息打断风格。
    func setBreakInterruptStyle(_ style: BreakInterruptStyle) {
        breakInterruptStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: MalDazeDefaults.breakInterruptStyle)
    }

    func quitApp() {
        NSApp.terminate(nil)
    }

    /// 测试休息结束后：若番茄/自动引擎仍在「休息段」内，需重新拉起霸屏（测试期间曾 `dismiss` 掉引擎那一轮）。
    private func resumeEngineRestOverlayIfNeeded() {
        switch mode {
        case .manual:
            if manualEngine.isTimerRunning && manualEngine.isInRestPhase {
                let remaining = manualEngine.restPhaseRemainingOrZero
                if remaining > 0 {
                    wasResting = true
                    presentRestWithCurrentStyle(duration: remaining) { }
                } else {
                    wasResting = false
                }
            } else {
                wasResting = false
            }
        case .auto:
            if autoEngine.isTimerRunning && autoEngine.isInScheduledRest {
                let remaining = autoEngine.scheduledRestRemainingOrZero
                if remaining > 0 {
                    wasResting = true
                    presentRestWithCurrentStyle(duration: remaining) { }
                } else {
                    wasResting = false
                }
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
                    presentRestWithCurrentStyle(duration: max(1, remaining), onDismissed: { })
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
