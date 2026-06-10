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

    enum RecommendationState: Equatable {
        case idle
        case fresh(NutritionRecommendationSnapshot)
        case stale(NutritionRecommendationSnapshot)
        case missing
        case unavailable(NutritionRecommendationSnapshot)
        case invalid(String)
    }

    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var recommendationState: RecommendationState = .idle
    @Published private(set) var loggableItems: [NutritionLoggableItem] = []
    @Published private(set) var isLogging = false
    @Published private(set) var loggingFlatIndex: Int?
    @Published var actionNotice: String?

    private let reader: any NutritionDailyLogReading
    private let recommendationReader: any NutritionRecommendationReading
    private let cli: any NutritionHermesCLI
    private var fileWatcher: NutritionDailyLogFileWatcher?
    private var recommendationFileWatcher: NutritionDailyLogFileWatcher?
    private var fsDebounceTask: Task<Void, Never>?
    private var lastPanelUpdatedAt: String?
    private var lastRecommendationGeneratedAt: String?
    private var pendingRefreshAfterLogging = false

    init(
        reader: any NutritionDailyLogReading = NutritionDailyLogContractReader(),
        recommendationReader: any NutritionRecommendationReading = NutritionRecommendationContractReader(),
        cli: any NutritionHermesCLI = ProcessNutritionHermesCLI()
    ) {
        self.reader = reader
        self.recommendationReader = recommendationReader
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
                lastRecommendationGeneratedAt = nil
                recommendationState = .idle
                loadState = .missingPanel
                return
            }
            updateRecommendationState(for: log, panel: panel)
            lastPanelUpdatedAt = panel.updatedAt
            loadState = .loaded(log)
        } catch let error as NutritionDailyLogContractError {
            loggableItems = []
            lastPanelUpdatedAt = nil
            lastRecommendationGeneratedAt = nil
            recommendationState = .idle
            loadState = .failed(NutritionDailyLogContractReader.userFacingMessage(for: error))
        } catch {
            loggableItems = []
            lastPanelUpdatedAt = nil
            lastRecommendationGeneratedAt = nil
            recommendationState = .idle
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

        let recommendationWatcher = NutritionDailyLogFileWatcher(fileURL: recommendationReader.fileURL) { [weak self] in
            Task { @MainActor in
                self?.scheduleDebouncedRefresh()
            }
        }
        recommendationFileWatcher = recommendationWatcher
        recommendationWatcher.start()
    }

    func stopWatching() {
        fsDebounceTask?.cancel()
        fsDebounceTask = nil
        fileWatcher?.stop()
        fileWatcher = nil
        recommendationFileWatcher?.stop()
        recommendationFileWatcher = nil
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

    func pollForExternalUpdates() {
        guard case .loaded = loadState else {
            loadToday()
            return
        }
        guard let onDisk = try? reader.read(), let panel = onDisk.panel else { return }
        let recommendationGeneratedAt = currentRecommendationGeneratedAt()
        if panel.updatedAt != lastPanelUpdatedAt ||
            recommendationGeneratedAt != lastRecommendationGeneratedAt {
            loadToday()
        }
    }

    var canUseDigitShortcuts: Bool {
        !isLogging && !loggableItems.isEmpty
    }

    var recommendationMessage: String? {
        switch recommendationState {
        case .idle, .fresh:
            return nil
        case .stale:
            return "Hermes 建议已过期，等待新的饮食建议。"
        case .missing:
            return NutritionRecommendationContractReader.userFacingMessage(for: .fileNotFound)
        case .unavailable(let snapshot):
            return snapshot.summary
        case .invalid(let message):
            return message
        }
    }

    private func updateRecommendationState(for log: NutritionDailyLog, panel: NutritionPanel) {
        do {
            let snapshot = try recommendationReader.read()
            lastRecommendationGeneratedAt = snapshot.generatedAt

            if snapshot.date == log.date,
               snapshot.basedOn.dailyLogPanelUpdatedAt == panel.updatedAt {
                if snapshot.state == .unavailable {
                    recommendationState = .unavailable(snapshot)
                    loggableItems = []
                } else {
                    recommendationState = .fresh(snapshot)
                    loggableItems = NutritionLoggableItem.flattened(from: snapshot)
                }
            } else {
                recommendationState = .stale(snapshot)
                loggableItems = []
            }
        } catch let error as NutritionRecommendationContractError {
            loggableItems = []
            lastRecommendationGeneratedAt = nil
            switch error {
            case .fileNotFound:
                recommendationState = .missing
            default:
                recommendationState = .invalid(NutritionRecommendationContractReader.userFacingMessage(for: error))
            }
        } catch {
            loggableItems = []
            lastRecommendationGeneratedAt = nil
            recommendationState = .invalid("读取 recommendation.json 失败。")
        }
    }

    private func currentRecommendationGeneratedAt() -> String? {
        (try? recommendationReader.read())?.generatedAt
    }
}
