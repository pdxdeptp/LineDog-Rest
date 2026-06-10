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

    struct T7LatestResultDisplay: Equatable {
        let statusText: String
        let runTimeText: String?
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
    /// 休息霸屏期间连续单击桌宠 10 下可提前结束休息（默认开）。
    @Published private(set) var restDoubleClickEndsRest: Bool
    /// 独立 7 分钟倒计时进行中（与桌宠无关）；结束后出现铃铛直至点击关闭。
    @Published private(set) var isSevenMinuteReminderRunning = false
    /// 独立 5 分钟小猫陪伴窗口是否正在显示（渐隐结束前为 true）。
    @Published private(set) var isFiveMinuteCatCompanionActive = false
    /// 喝水提醒已调度（计时中或浮层待操作）为 true；开关关闭或调用 cancel 后变 false。
    @Published private(set) var isHydrationReminderEnabled: Bool
    /// 睡眠提醒总开关（UserDefaults）；调度成功且契约有效时为 true。
    @Published private(set) var isSleepScheduleEnabled: Bool
    /// 睡眠契约无效或读取失败时的用户可见说明；nil 表示正常。
    @Published private(set) var sleepScheduleError: String?
    /// 睡眠提醒调度快照（契约目标、计划时刻、桌宠上次读 JSON 时间）。
    @Published private(set) var sleepScheduleStatus: SleepReminderScheduleSnapshot?
    /// Hermes 强提醒契约无效或读取失败时的说明；nil 表示正常。
    @Published private(set) var interventionRequestError: String?
    /// 休息打断风格，持久化到 UserDefaults。
    @Published private(set) var breakInterruptStyle: BreakInterruptStyle

    /// 提醒事项同步（EventKit）；与菜单栏、桌宠 Dashboard 共用。
    let deskReminders: DeskRemindersModel
    /// 桌宠 Dashboard Esc 分级：sheet / 对话框优先于关面板。
    let dashboardEscapeRouter = DeskPetDashboardEscapeRouter()

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
    /// 睡前提醒链；只读 Hermes `sleep_schedule.json`。
    private let sleepReminder: SleepReminderController
    /// Hermes 强提醒；只读 `intervention_request.json`。
    private let interventionRequest: InterventionRequestController
    /// T7 安全推出服务；调度生命周期绑定在 AppViewModel 内。
    let t7EjectService: any T7EjectServiceLifecycle
    private let t7EjectUIService: (any T7EjectServiceUIControlling)?

    private var wasResting = false
    private var testRestActive = false
    private var cachedStatusLine: String = "自动模式：正在对齐系统时钟…"
    /// 避免 `syncPetDisplayMode` 在计时器 tick 中重复调用 `WindowManager`（模式未变时）。
    private var lastIdlePetModeAppliedToWindow: PetDisplayMode?
    /// 智能输入等待 LLM 时，桌宠与菜单栏显示「思考」态。
    private var smartReminderThinkingActive = false
    private var smartReminderShortcutObserver: NSObjectProtocol?
    private var deskPetMenuShortcutObserver: NSObjectProtocol?
    private var focusDashboardFromDockObserver: NSObjectProtocol?
    private var sevenMinuteShortcutObserver: NSObjectProtocol?
    private var resetIdlePetShortcutObserver: NSObjectProtocol?
    private var idlePetIconSidePointsObserver: NSObjectProtocol?
    private var idlePetAnimationIntensityObserver: NSObjectProtocol?
    private var sleepScheduleSettingsObserver: NSObjectProtocol?
    private var autoTimerWakeObserver: NSObjectProtocol?
    private var autoTimerBecomeActiveObserver: NSObjectProtocol?
    /// 智能提醒写入的 `EKAlarm` 到点后弹出与 7 分钟倒计时相同的中央铃铛。
    private var smartReminderBellTasks: [String: Task<Void, Never>] = [:]

    private static var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    private static func shouldBootstrapT7EjectScheduler(explicitValue: Bool?) -> Bool {
        explicitValue ?? !isRunningUnderXCTest
    }

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
        sleepReminder: SleepReminderController? = nil,
        interventionRequest: InterventionRequestController? = nil,
        deskReminders: DeskRemindersModel? = nil,
        t7EjectService: (any T7EjectServiceLifecycle)? = nil,
        bootstrapT7EjectScheduler: Bool? = nil
    ) {
        self.windowManager = windowManager
        let resolvedSevenMinuteReminder = sevenMinuteReminder ?? SevenMinuteReminderController()
        self.sevenMinuteReminder = resolvedSevenMinuteReminder
        self.fiveMinuteCatCompanion = fiveMinuteCatCompanion ?? FiveMinuteCatCompanionController()
        self.hydrationReminder = hydrationReminder ?? HydrationReminderController()
        self.sleepReminder = sleepReminder ?? SleepReminderController(
            bellPresenter: resolvedSevenMinuteReminder,
            windowManager: windowManager
        )
        self.interventionRequest = interventionRequest ?? InterventionRequestController(
            bellPresenter: resolvedSevenMinuteReminder
        )
        let resolvedT7EjectService = t7EjectService ?? T7EjectService.live()
        self.t7EjectService = resolvedT7EjectService
        self.t7EjectUIService = resolvedT7EjectService as? any T7EjectServiceUIControlling
        T7EjectAppLifecycleRegistry.shared.register(resolvedT7EjectService)
        self.isHydrationReminderEnabled = UserDefaults.standard.bool(forKey: MalDazeDefaults.hydrationReminderEnabled)
        self.isSleepScheduleEnabled = MalDazeDefaults.resolvedSleepScheduleEnabled()
        self.sleepScheduleError = nil
        let rawStyle = UserDefaults.standard.string(forKey: MalDazeDefaults.breakInterruptStyle) ?? ""
        self.breakInterruptStyle = BreakInterruptStyle(rawValue: rawStyle) ?? .fullscreen
        self.deskReminders = deskReminders ?? DeskRemindersModel()
        self.smartReminderOrchestrator = SmartReminderOrchestrator()
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
        let suspendedModeSnapshot = bootstrapAutoEngine ? Self.validSuspendedTimerModeSnapshot(defaults: ud) : nil
        self.isChronoSessionActive = bootstrapAutoEngine && suspendedModeSnapshot == nil
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

        if let suspendedModeSnapshot {
            mode = suspendedModeSnapshot
            chronoSessionSuspendedByUser = true
            switch suspendedModeSnapshot {
            case .manual:
                statusLine = "已暂停。点击「恢复计时」继续，或再次「开始专注」开新一轮。"
            case .auto:
                statusLine = "自动提醒已暂停。点击「恢复计时」重新对齐整点 / 半点。"
            }
            cachedStatusLine = statusLine
        } else if !bootstrapAutoEngine {
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

        // 总开关仅由 UserDefaults / setSleepScheduleEnabled 驱动；调度成败不覆写开关，避免 UI 被藏起。
        self.sleepReminder.onScheduleStateChanged = { _ in }
        self.sleepReminder.onError = { [weak self] message in
            self?.sleepScheduleError = message
        }
        self.sleepReminder.onSnapshotChanged = { [weak self] snapshot in
            self?.sleepScheduleStatus = snapshot
        }
        self.sleepReminder.onDismissTimerRestForSleepLock = { [weak self] in
            guard let self else { return }
            if self.testRestActive || self.wasResting {
                self.windowManager.dismissRestImmediately(bringIdlePetWindowToFront: false)
            }
        }
        if self.isSleepScheduleEnabled {
            self.sleepReminder.start()
        }

        self.interventionRequest.onError = { [weak self] message in
            self?.interventionRequestError = message
        }
        self.interventionRequest.start()

        if Self.shouldBootstrapT7EjectScheduler(explicitValue: bootstrapT7EjectScheduler) {
            self.t7EjectService.startScheduler()
        }

        self.deskReminders.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        if let observableT7Service = resolvedT7EjectService as? T7EjectService {
            observableT7Service.objectWillChange
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }

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

        focusDashboardFromDockObserver = NotificationCenter.default.addObserver(
            forName: MalDazeBroadcastNotifications.focusDashboardFromDock,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showOrFocusDashboardFromDock()
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

        sleepScheduleSettingsObserver = NotificationCenter.default.addObserver(
            forName: MalDazeBroadcastNotifications.sleepScheduleSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncSleepScheduleFromUserDefaults()
        }

        installAutoTimerLifecycleObserversIfNeeded()
    }

    private func installAutoTimerLifecycleObserversIfNeeded() {
        if autoTimerWakeObserver == nil {
            autoTimerWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.realignAutomaticTimerAfterLifecycleEvent()
                }
            }
        }
        if autoTimerBecomeActiveObserver == nil {
            autoTimerBecomeActiveObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.realignAutomaticTimerAfterLifecycleEvent()
                }
            }
        }
    }

    private func realignAutomaticTimerAfterLifecycleEvent() {
        guard
            mode == .auto,
            isChronoSessionActive,
            !chronoSessionSuspendedByUser,
            !autoEngine.isInScheduledRest
        else { return }
        autoEngine.realignWatching()
    }

    private func syncSleepScheduleFromUserDefaults() {
        let enabled = MalDazeDefaults.resolvedSleepScheduleEnabled()
        if enabled {
            if !isSleepScheduleEnabled {
                setSleepScheduleEnabled(true)
            } else {
                sleepReminder.reloadAndReschedule()
            }
        } else if isSleepScheduleEnabled {
            setSleepScheduleEnabled(false)
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

    var t7LatestResult: T7EjectResult? {
        t7EjectService.latestResult
    }

    var isT7EjectRunning: Bool {
        t7EjectService.isRunning
    }

    var isT7AutomaticEjectEnabled: Bool {
        t7EjectService.isAutomaticEnabled
    }

    var t7ScheduleConfiguration: T7EjectScheduleConfiguration {
        t7EjectUIService?.scheduleConfiguration ?? .default
    }

    var isT7ManualEjectAvailable: Bool {
        !isT7EjectRunning
    }

    var t7LatestResultDisplay: T7LatestResultDisplay {
        Self.t7LatestResultDisplay(for: t7LatestResult)
    }

    @discardableResult
    func runT7ManualEject() async -> T7EjectResult {
        guard let t7EjectUIService else {
            let now = Date()
            return T7EjectResult(
                status: .failed,
                reason: .unexpectedError,
                action: .safeEject,
                wholeDisk: nil,
                apfsContainer: nil,
                volumes: [],
                timeMachineWasRunning: false,
                timeMachineStopped: false,
                remainingMountedVolumes: [],
                dissenterStatus: nil,
                dissenterMessage: "T7 eject service does not expose UI commands.",
                startedAt: now,
                endedAt: now,
                message: T7EjectResult.message(for: .failed, reason: .unexpectedError)
            )
        }
        let result = await t7EjectUIService.runManualEject()
        objectWillChange.send()
        return result
    }

    func setT7AutomaticEjectEnabled(_ enabled: Bool) {
        t7EjectUIService?.setAutomaticEnabled(enabled)
        objectWillChange.send()
    }

    func updateT7ScheduleConfiguration(_ configuration: T7EjectScheduleConfiguration) {
        t7EjectUIService?.updateScheduleConfiguration(configuration)
        objectWillChange.send()
    }

    static func t7LatestResultDisplay(
        for result: T7EjectResult?,
        calendar: Calendar = .current
    ) -> T7LatestResultDisplay {
        guard let result else {
            return T7LatestResultDisplay(statusText: "尚未运行", runTimeText: nil)
        }
        let components = calendar.dateComponents([.hour, .minute], from: result.endedAt)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return T7LatestResultDisplay(
            statusText: t7LatestResultStatusText(for: result),
            runTimeText: String(format: "上次运行：%02d:%02d", hour, minute)
        )
    }

    private static func t7LatestResultStatusText(for result: T7EjectResult) -> String {
        guard result.status == .failed else {
            return result.message
        }

        switch result.reason {
        case .diskBusy:
            return "T7 正在被占用，未强制推出。"
        case .diskArbitrationDissented:
            return "macOS 拒绝推出 T7，未强制推出。"
        case .timeMachineStillRunning:
            return "Time Machine 仍在运行，未强制推出 T7。"
        case .unsafeTargetMultipleDisks:
            return "T7 目标解析到多个磁盘，未强制推出。"
        case .unsafeTargetInternalDisk:
            return "目标看起来是内部磁盘，未强制推出。"
        case .unmountSucceededEjectFailed:
            return "T7 已卸载，但未强制推出。"
        case .unexpectedError:
            return "T7 推出时遇到未知错误，未强制推出。"
        default:
            return "T7 未强制推出，请稍后重试。"
        }
    }

    deinit {
        let t7 = t7EjectService
        Task { @MainActor in
            T7EjectAppLifecycleRegistry.shared.unregister(t7)
            t7.stop()
        }
        let h = hydrationReminder
        Task { @MainActor in h.cancel() }
        let sleep = sleepReminder
        Task { @MainActor in sleep.cancel() }
        if let smartReminderShortcutObserver {
            NotificationCenter.default.removeObserver(smartReminderShortcutObserver)
        }
        if let deskPetMenuShortcutObserver {
            NotificationCenter.default.removeObserver(deskPetMenuShortcutObserver)
        }
        if let focusDashboardFromDockObserver {
            NotificationCenter.default.removeObserver(focusDashboardFromDockObserver)
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
        if let sleepScheduleSettingsObserver {
            NotificationCenter.default.removeObserver(sleepScheduleSettingsObserver)
        }
        if let autoTimerWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(autoTimerWakeObserver)
        }
        if let autoTimerBecomeActiveObserver {
            NotificationCenter.default.removeObserver(autoTimerBecomeActiveObserver)
        }
    }

    private func presentDeskPetMenuFromGlobalShortcut() {
        windowManager.presentDeskMenuFromGlobalShortcut()
    }

    private func showOrFocusDashboardFromDock() {
        windowManager.showOrFocusDashboardFromDock()
    }

    private static func validSuspendedTimerModeSnapshot(defaults: UserDefaults = .standard) -> Mode? {
        guard defaults.object(forKey: MalDazeDefaults.suspendedTimerModeSnapshot) != nil else {
            return nil
        }
        guard let rawMode = defaults.string(forKey: MalDazeDefaults.suspendedTimerModeSnapshot) else {
            defaults.removeObject(forKey: MalDazeDefaults.suspendedTimerModeSnapshot)
            return nil
        }
        guard let mode = mode(forSuspendedTimerModeSnapshotToken: rawMode) else {
            defaults.removeObject(forKey: MalDazeDefaults.suspendedTimerModeSnapshot)
            return nil
        }
        return mode
    }

    private func persistSuspendedTimerModeSnapshot() {
        UserDefaults.standard.set(Self.suspendedTimerModeSnapshotToken(for: mode), forKey: MalDazeDefaults.suspendedTimerModeSnapshot)
    }

    private func clearSuspendedTimerModeSnapshot() {
        UserDefaults.standard.removeObject(forKey: MalDazeDefaults.suspendedTimerModeSnapshot)
    }

    private static func suspendedTimerModeSnapshotToken(for mode: Mode) -> String {
        switch mode {
        case .manual:
            return "manual"
        case .auto:
            return "auto"
        }
    }

    private static func mode(forSuspendedTimerModeSnapshotToken token: String) -> Mode? {
        switch token {
        case "manual":
            return .manual
        case "auto":
            return .auto
        default:
            return nil
        }
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

    /// 手动预览睡眠排程中的下一项（仅 `deliver`，不标记已触发、不影响 Timer）。
    @discardableResult
    func testFireNextSleepReminder() -> String {
        sleepReminder.testing_fireNextScheduledReminder()
    }

    func setSleepScheduleEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: MalDazeDefaults.sleepScheduleEnabled)
        isSleepScheduleEnabled = enabled
        if enabled {
            sleepReminder.start()
        } else {
            sleepScheduleError = nil
            sleepScheduleStatus = nil
            sleepReminder.cancel()
        }
    }

    func setSleepScheduleRemindersEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: MalDazeDefaults.sleepScheduleRemindersEnabled)
        if isSleepScheduleEnabled { sleepReminder.reloadAndReschedule() }
    }

    func setSleepScheduleLockScreenEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: MalDazeDefaults.sleepScheduleLockScreenEnabled)
        if isSleepScheduleEnabled { sleepReminder.reloadAndReschedule() }
    }

    func setSleepScheduleDismissOnClamshell(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: MalDazeDefaults.sleepScheduleDismissOnClamshell)
    }

    func setSleepScheduleShowerReminderEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: MalDazeDefaults.sleepScheduleShowerReminderEnabled)
        if isSleepScheduleEnabled { sleepReminder.reloadAndReschedule() }
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
        clearSuspendedTimerModeSnapshot()

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
        clearSuspendedTimerModeSnapshot()
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
        persistSuspendedTimerModeSnapshot()
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
        clearSuspendedTimerModeSnapshot()
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

    /// 休息全屏中央小狗**连续单击 10 下**：收起霸屏，并让计时引擎退出当前休息段（测试休息则走与普通结束相同的回调）。
    /// 若用户在设置中关闭「单击 10 下桌宠结束休息」，本函数直接返回。
    func endRestEarlyFromDeskPet() {
        guard restDoubleClickEndsRest else { return }
        if sleepReminder.isSleepLockActive {
            windowManager.dismissRestImmediately(bringIdlePetWindowToFront: false)
            sleepReminder.clearSleepLockActiveFlag()
            return
        }
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
        T7EjectAppLifecycleRegistry.shared.stopRegisteredService()
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
