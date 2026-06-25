import AppKit
import Foundation

/// 消费 Hermes `intervention_request.json` 并驱动倒计时 / 中央铃铛。
@MainActor
final class InterventionRequestController {
    var onError: ((String?) -> Void)?

    private let contractReader: InterventionRequestContractReader
    private let ackStore: InterventionRequestAckStore
    private let bellPresenter: SevenMinuteReminderController
    private var fileWatcher: InterventionRequestFileWatcher?
    private var wakeObserver: NSObjectProtocol?
    private var becomeActiveObserver: NSObjectProtocol?

    init(
        contractReader: InterventionRequestContractReader = InterventionRequestContractReader(),
        ackStore: InterventionRequestAckStore = InterventionRequestAckStore(),
        bellPresenter: SevenMinuteReminderController
    ) {
        self.contractReader = contractReader
        self.ackStore = ackStore
        self.bellPresenter = bellPresenter
    }

    func start() {
        installLifecycleObserversIfNeeded()
        startFileWatcher()
        processPendingIfNeeded()
    }

    func cancel() {
        removeLifecycleObservers()
        stopFileWatcher()
        onError?(nil)
    }

    func reloadAndProcess() {
        processPendingIfNeeded()
    }

    // MARK: - Processing

    private func processPendingIfNeeded() {
        let pendingURL = contractReader.fileURL
        guard FileManager.default.fileExists(atPath: pendingURL.path) else {
            onError?(nil)
            return
        }

        do {
            let contract = try contractReader.read()

            if ackStore.hasConsumed(id: contract.id) {
                try? FileManager.default.removeItem(at: pendingURL)
                onError?(nil)
                return
            }

            let now = Date()
            if contract.isExpired(at: now) {
                try ackStore.markConsumed(pendingFileURL: pendingURL, contract: contract)
                onError?(nil)
                return
            }

            switch contract.kind {
            case .countdown:
                try executeCountdown(contract: contract, now: now, pendingURL: pendingURL)
            case .bell:
                bellPresenter.presentCenterBellReminder(message: contract.title)
                try ackStore.markConsumed(pendingFileURL: pendingURL, contract: contract)
            case .cancel:
                bellPresenter.cancel()
                try ackStore.markConsumed(pendingFileURL: pendingURL, contract: contract)
            }

            onError?(nil)
        } catch let error as InterventionRequestContractError {
            onError?(Self.message(for: error))
        } catch {
            onError?(error.localizedDescription)
        }
    }

    private func executeCountdown(
        contract: InterventionRequestContract,
        now: Date,
        pendingURL: URL
    ) throws {
        guard let minutes = contract.minutes else {
            throw InterventionRequestContractError.missingField("minutes")
        }

        if contract.isCountdownPastDue(at: now) {
            bellPresenter.presentCenterBellReminder(message: contract.title)
            try ackStore.markConsumed(pendingFileURL: pendingURL, contract: contract)
            return
        }

        bellPresenter.cancel()
        bellPresenter.start(minutes: minutes, completionMessage: contract.title)
        try ackStore.markConsumed(pendingFileURL: pendingURL, contract: contract)
    }

    private static func message(for error: InterventionRequestContractError) -> String {
        switch error {
        case .fileNotFound:
            return "强提醒契约文件不存在。"
        case .readFailed:
            return "无法读取强提醒契约。"
        case .invalidJSON:
            return "强提醒契约 JSON 无效。"
        case .missingField(let field):
            return "强提醒契约缺少字段：\(field)。"
        case .invalidKind(let kind):
            return "强提醒契约 kind 无效：\(kind)。"
        case .invalidSchemaVersion(let v):
            return "强提醒契约 schemaVersion 无效：\(v)。"
        case .invalidMinutes:
            return "强提醒 countdown 的 minutes 必须为正整数。"
        case .invalidDate(let raw):
            return "强提醒契约日期无效：\(raw)。"
        }
    }

    // MARK: - Lifecycle

    private func installLifecycleObserversIfNeeded() {
        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.processPendingIfNeeded()
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
                    self?.processPendingIfNeeded()
                }
            }
        }
    }

    private func removeLifecycleObservers() {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        if let becomeActiveObserver {
            NotificationCenter.default.removeObserver(becomeActiveObserver)
            self.becomeActiveObserver = nil
        }
    }

    private func startFileWatcher() {
        guard fileWatcher == nil else { return }
        let watcher = InterventionRequestFileWatcher { [weak self] in
            Task { @MainActor [weak self] in
                self?.processPendingIfNeeded()
            }
        }
        watcher.start()
        fileWatcher = watcher
    }

    private func stopFileWatcher() {
        fileWatcher?.stop()
        fileWatcher = nil
    }
}
