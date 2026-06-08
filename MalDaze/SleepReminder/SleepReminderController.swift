import AppKit
import Foundation

/// 睡前提醒：幂等 reconcile + 多一次性 Timer + 已触发记录。
@MainActor
final class SleepReminderController {
    var onScheduleStateChanged: ((Bool) -> Void)?
    var onError: ((String?) -> Void)?
    var onSnapshotChanged: ((SleepReminderScheduleSnapshot?) -> Void)?
    /// 睡眠霸屏前收起计时器休息 overlay（不 skip 引擎）。
    var onDismissTimerRestForSleepLock: (() -> Void)?

    private(set) var isSleepLockActive = false

    private let contractReader: SleepScheduleContractReader
    private let bellPresenter: SevenMinuteReminderController
    private let windowManager: WindowManaging
    private let firedStore: SleepReminderFiredStore
    private var contractFileWatcher: SleepScheduleFileWatcher?
    private var eventTimers: [String: Timer] = [:]
    private var scheduledItems: [SleepReminderScheduledItem] = []
    private var firedEventIDs: Set<String> = []
    private var lastLoadedContract: SleepScheduleContract?
    private var lastSnapshotReadAt: Date?
    private var wakeObserver: NSObjectProtocol?
    private var willSleepObserver: NSObjectProtocol?
    private var becomeActiveObserver: NSObjectProtocol?
    private var wakeDelayedReconcileTimer: Timer?
    private var watchdogTimer: Timer?

    private static let sleepLockDuration: TimeInterval = 30 * 60

    init(
        contractReader: SleepScheduleContractReader = SleepScheduleContractReader(),
        bellPresenter: SevenMinuteReminderController,
        windowManager: WindowManaging,
        firedStore: SleepReminderFiredStore = SleepReminderFiredStore()
    ) {
        self.contractReader = contractReader
        self.bellPresenter = bellPresenter
        self.windowManager = windowManager
        self.firedStore = firedStore
    }

    func start() {
        cancelAllEventTimers()
        installLifecycleObserversIfNeeded()
        startContractFileWatcher()
        reconcile()
        refreshWatchdogTimer()
    }

    func cancel() {
        removeLifecycleObservers()
        cancelAllEventTimers()
        cancelWakeDelayedReconcileTimer()
        stopWatchdogTimer()
        scheduledItems = []
        firedEventIDs = []
        lastLoadedContract = nil
        lastSnapshotReadAt = nil
        stopContractFileWatcher()
        if isSleepLockActive {
            windowManager.dismissRestImmediately(bringIdlePetWindowToFront: false)
            isSleepLockActive = false
        }
        bellPresenter.dismissCenterBellReminderIfShowing()
        onScheduleStateChanged?(false)
        onError?(nil)
        onSnapshotChanged?(nil)
    }

    func reloadAndReschedule() {
        reconcile()
    }

    // MARK: - Reconcile

    private func reconcile() {
        guard Self.isMasterEnabled() else {
            cancel()
            return
        }

        let readAt = Date()

        do {
            let contract = try contractReader.read()
            firedEventIDs = firedStore.loadFiredIDs(for: contract.updatedAt)
            lastLoadedContract = contract
            lastSnapshotReadAt = readAt
            onError?(nil)

            let items = SleepReminderReconciler.buildSchedule(
                contract: contract,
                settings: Self.loadUserSettings(),
                now: readAt,
                firedIDs: firedEventIDs
            )
            scheduledItems = items

            cancelAllEventTimers()

            for item in SleepReminderReconciler.catchUpItems(in: items) {
                deliver(item.event)
                markFired(stableID: item.stableID, contract: contract)
            }

            for item in SleepReminderReconciler.pendingTimerItems(in: items) {
                scheduleTimer(for: item, contract: contract)
            }

            onScheduleStateChanged?(true)
            publishSnapshot(lastReadAt: readAt, contract: contract)
            refreshWatchdogTimer()
        } catch let error as SleepScheduleContractError {
            scheduledItems = []
            firedEventIDs = []
            lastLoadedContract = nil
            cancelAllEventTimers()
            onError?(SleepScheduleContractReader.userFacingMessage(for: error))
            onScheduleStateChanged?(false)
            lastSnapshotReadAt = readAt
            onSnapshotChanged?(SleepReminderScheduleSnapshotBuilder.failedRead(at: readAt))
            stopWatchdogTimer()
        } catch {
            onError?("睡眠配置读取失败。")
            onScheduleStateChanged?(false)
            lastSnapshotReadAt = readAt
            onSnapshotChanged?(SleepReminderScheduleSnapshotBuilder.failedRead(at: readAt))
            stopWatchdogTimer()
        }
    }

    private func markFired(stableID: String, contract: SleepScheduleContract) {
        firedEventIDs.insert(stableID)
        firedStore.save(firedIDs: firedEventIDs, contractUpdatedAt: contract.updatedAt)
        scheduledItems = scheduledItems.map { item in
            guard item.stableID == stableID else { return item }
            return SleepReminderScheduledItem(event: item.event, stableID: item.stableID, state: .fired)
        }
        if let readAt = lastSnapshotReadAt {
            publishSnapshot(lastReadAt: readAt, contract: contract)
        }
    }

    /// 测试用：仅预览下一项提醒 UI；不 `markFired`、不取消 Timer，不影响原计划到点执行。
    @discardableResult
    func testing_fireNextScheduledReminder() -> String {
        guard Self.isMasterEnabled() else {
            return "请先开启睡眠提醒总开关。"
        }
        if lastLoadedContract == nil {
            reconcile()
        }
        guard lastLoadedContract != nil else {
            return "无法读取睡眠契约，请确认 Hermes JSON 有效。"
        }
        guard let index = SleepReminderReconciler.nextActionableIndex(in: scheduledItems) else {
            return "当前没有待触发的睡眠提醒。"
        }
        let item = scheduledItems[index]
        deliver(item.event)
        return "已预览：\(item.event.kind.scheduleTitle)（不影响定时计划）"
    }

    private func scheduleTimer(for item: SleepReminderScheduledItem, contract: SleepScheduleContract) {
        let fireDate = max(item.event.fireDate, Date().addingTimeInterval(0.25))
        let stableID = item.stableID
        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.fireScheduledItem(item, contract: contract)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        eventTimers[stableID] = timer
    }

    private func fireScheduledItem(_ item: SleepReminderScheduledItem, contract: SleepScheduleContract) {
        eventTimers[item.stableID]?.invalidate()
        eventTimers[item.stableID] = nil
        deliver(item.event)
        markFired(stableID: item.stableID, contract: contract)
    }

    private func deliver(_ event: SleepReminderEvent) {
        switch event.kind {
        case .shower, .wrapUp, .washUp, .deadlineBell:
            bellPresenter.presentCenterBellReminder(message: event.message)
        case .lockScreen:
            triggerSleepLock(bellMessage: event.message)
        }
    }

    private func triggerSleepLock(bellMessage: String) {
        onDismissTimerRestForSleepLock?()
        bellPresenter.presentCenterBellReminder(message: bellMessage)
        isSleepLockActive = true
        windowManager.presentRest(duration: Self.sleepLockDuration) { [weak self] in
            self?.isSleepLockActive = false
        }
    }

    private func cancelAllEventTimers() {
        for timer in eventTimers.values {
            timer.invalidate()
        }
        eventTimers.removeAll()
    }

    private func publishSnapshot(lastReadAt: Date, contract: SleepScheduleContract) {
        onSnapshotChanged?(
            SleepReminderScheduleSnapshotBuilder.make(
                contract: contract,
                items: scheduledItems,
                lastReadAt: lastReadAt
            )
        )
    }

    // MARK: - Settings

    static func isMasterEnabled() -> Bool {
        MalDazeDefaults.resolvedSleepScheduleEnabled()
    }

    static func loadUserSettings() -> SleepReminderUserSettings {
        let ud = UserDefaults.standard
        func boolDefaultTrue(_ key: String) -> Bool {
            ud.object(forKey: key) == nil ? true : ud.bool(forKey: key)
        }
        return SleepReminderUserSettings(
            remindersEnabled: boolDefaultTrue(MalDazeDefaults.sleepScheduleRemindersEnabled),
            lockScreenEnabled: boolDefaultTrue(MalDazeDefaults.sleepScheduleLockScreenEnabled),
            showerReminderEnabled: boolDefaultTrue(MalDazeDefaults.sleepScheduleShowerReminderEnabled)
        )
    }

    static func isDismissOnClamshellEnabled() -> Bool {
        let ud = UserDefaults.standard
        return ud.object(forKey: MalDazeDefaults.sleepScheduleDismissOnClamshell) == nil
            ? true
            : ud.bool(forKey: MalDazeDefaults.sleepScheduleDismissOnClamshell)
    }

    // MARK: - Lifecycle

    private func removeLifecycleObservers() {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        if let willSleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(willSleepObserver)
            self.willSleepObserver = nil
        }
        if let becomeActiveObserver {
            NotificationCenter.default.removeObserver(becomeActiveObserver)
            self.becomeActiveObserver = nil
        }
    }

    private func installLifecycleObserversIfNeeded() {
        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleDidWake()
                }
            }
        }
        if willSleepObserver == nil {
            willSleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleWillSleep()
                }
            }
        }
        if becomeActiveObserver == nil {
            becomeActiveObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reconcile()
                }
            }
        }
    }

    private func handleDidWake() {
        reconcile()
        scheduleWakeDelayedReconcile()
    }

    private func scheduleWakeDelayedReconcile() {
        cancelWakeDelayedReconcileTimer()
        let fireDate = Date().addingTimeInterval(SleepReminderSchedulingPolicy.wakeDelayedReconcile)
        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.wakeDelayedReconcileTimer = nil
                self?.reconcile()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        wakeDelayedReconcileTimer = timer
    }

    private func cancelWakeDelayedReconcileTimer() {
        wakeDelayedReconcileTimer?.invalidate()
        wakeDelayedReconcileTimer = nil
    }

    private func refreshWatchdogTimer() {
        guard Self.isMasterEnabled(),
              SleepReminderSchedulingPolicy.isInSleepWatchdogWindow(now: Date())
        else {
            stopWatchdogTimer()
            return
        }
        guard watchdogTimer == nil else { return }

        let timer = Timer(
            timeInterval: SleepReminderSchedulingPolicy.watchdogInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if SleepReminderSchedulingPolicy.isInSleepWatchdogWindow(now: Date()) {
                    self.reconcile()
                } else {
                    self.stopWatchdogTimer()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdogTimer = timer
    }

    private func stopWatchdogTimer() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    private func startContractFileWatcher() {
        stopContractFileWatcher()
        let watcher = SleepScheduleFileWatcher(fileURL: contractReader.fileURL) { [weak self] in
            Task { @MainActor [weak self] in
                self?.reconcile()
            }
        }
        watcher.start()
        contractFileWatcher = watcher
    }

    private func stopContractFileWatcher() {
        contractFileWatcher?.stop()
        contractFileWatcher = nil
    }

    private func handleWillSleep() {
        guard Self.isDismissOnClamshellEnabled() else { return }
        bellPresenter.dismissCenterBellReminderIfShowing()
        guard isSleepLockActive else { return }
        windowManager.dismissRestImmediately(bringIdlePetWindowToFront: false)
        isSleepLockActive = false
    }

    func clearSleepLockActiveFlag() {
        isSleepLockActive = false
    }

    /// 单测：模拟 `lockBedtime` 霸屏已激活，用于合盖取消路径。
    func testing_setSleepLockActiveForTests(_ active: Bool) {
        isSleepLockActive = active
    }
}
