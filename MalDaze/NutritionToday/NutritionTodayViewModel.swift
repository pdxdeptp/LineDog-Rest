import Foundation

@MainActor
final class NutritionTodayViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(NutritionDailyLog)
        case missingPanel
        case failed(String)
    }

    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var loggableItems: [NutritionLoggableItem] = []
    @Published private(set) var isLogging = false
    @Published private(set) var loggingFlatIndex: Int?
    @Published var actionNotice: String?

    private let reader: any NutritionDailyLogReading
    private let cli: any NutritionHermesCLI
    private var fileWatcher: NutritionDailyLogFileWatcher?
    private var fsDebounceTask: Task<Void, Never>?
    private var stalePollTask: Task<Void, Never>?
    private var lastPanelUpdatedAt: String?
    private var pendingRefreshAfterLogging = false

    init(
        reader: any NutritionDailyLogReading = NutritionDailyLogContractReader(),
        cli: any NutritionHermesCLI = ProcessNutritionHermesCLI()
    ) {
        self.reader = reader
        self.cli = cli
    }

    func loadToday(showLoading: Bool = true) {
        if showLoading {
            loadState = .loading
        }
        do {
            let log = try reader.read()
            guard let panel = log.panel else {
                loggableItems = []
                lastPanelUpdatedAt = nil
                loadState = .missingPanel
                return
            }
            loggableItems = NutritionLoggableItem.flattened(from: panel)
            lastPanelUpdatedAt = panel.updatedAt
            loadState = .loaded(log)
        } catch let error as NutritionDailyLogContractError {
            loggableItems = []
            lastPanelUpdatedAt = nil
            loadState = .failed(NutritionDailyLogContractReader.userFacingMessage(for: error))
        } catch {
            loggableItems = []
            lastPanelUpdatedAt = nil
            loadState = .failed("读取饮食数据失败。")
        }
    }

    func logItem(flatIndex: Int) async {
        guard !isLogging else { return }
        guard let item = loggableItems.first(where: { $0.flatIndex == flatIndex }) else { return }

        isLogging = true
        loggingFlatIndex = flatIndex
        actionNotice = nil

        var shouldReload = false
        defer {
            isLogging = false
            loggingFlatIndex = nil
            if shouldReload {
                loadToday(showLoading: false)
            } else if pendingRefreshAfterLogging {
                pendingRefreshAfterLogging = false
                scheduleDebouncedRefresh()
            }
        }

        do {
            try await cli.logFood(name: item.name, grams: item.grams)
            shouldReload = true
        } catch let error as NutritionCLIError {
            actionNotice = error.message
        } catch {
            actionNotice = error.localizedDescription
        }
    }

    func startWatching() {
        guard fileWatcher == nil else { return }
        let watcher = NutritionDailyLogFileWatcher(fileURL: reader.fileURL) { [weak self] in
            Task { @MainActor in
                self?.scheduleDebouncedRefresh()
            }
        }
        fileWatcher = watcher
        watcher.start()
        startStalePollingIfNeeded()
    }

    func stopWatching() {
        fsDebounceTask?.cancel()
        fsDebounceTask = nil
        stalePollTask?.cancel()
        stalePollTask = nil
        fileWatcher?.stop()
        fileWatcher = nil
    }

    func scheduleDebouncedRefresh() {
        if isLogging {
            pendingRefreshAfterLogging = true
            return
        }
        fsDebounceTask?.cancel()
        fsDebounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled, !isLogging else { return }
            loadToday()
        }
    }

    private func startStalePollingIfNeeded() {
        stalePollTask?.cancel()
        stalePollTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 45_000_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled, !isLogging else { continue }
                pollIfPanelStale()
            }
        }
    }

    private func pollIfPanelStale() {
        guard case .loaded = loadState else {
            loadToday()
            return
        }
        guard let onDisk = try? reader.read(), let panel = onDisk.panel else { return }
        if panel.updatedAt != lastPanelUpdatedAt {
            loadToday()
        }
    }

    var canUseDigitShortcuts: Bool {
        !isLogging && !loggableItems.isEmpty
    }
}
