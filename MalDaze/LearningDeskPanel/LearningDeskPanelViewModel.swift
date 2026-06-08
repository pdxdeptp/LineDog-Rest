import Foundation

@MainActor
final class LearningDeskPanelViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(LearningTodaySnapshot)
        case failed(String)
    }

    struct MovePreview: Identifiable, Equatable {
        let id: String
        let taskId: String
        let taskTitle: String
        let newDate: String
        let changes: [HermesMoveChange]
    }

    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var busyTaskIds: Set<String> = []
    @Published var movePreview: MovePreview?
    @Published var actionNotice: String?

    private let cli: any HermesScheduleCLI

    init(cli: any HermesScheduleCLI = ProcessHermesScheduleCLI()) {
        self.cli = cli
    }

    func loadToday() async {
        loadState = .loading
        actionNotice = nil
        do {
            try await cli.runRollover()
            let today = try await cli.fetchToday()
            loadState = .loaded(LearningTodaySnapshot.make(from: today))
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func complete(taskId: String) async {
        busyTaskIds.insert(taskId)
        defer { busyTaskIds.remove(taskId) }
        do {
            let result = try await cli.complete(taskId: taskId)
            guard result.succeeded else {
                actionNotice = result.error ?? "完成失败"
                return
            }
            await loadToday()
        } catch {
            actionNotice = error.localizedDescription
        }
    }

    func requestMove(taskId: String, taskTitle: String, newDate: String) async {
        busyTaskIds.insert(taskId)
        defer { busyTaskIds.remove(taskId) }
        do {
            let preview = try await cli.move(taskId: taskId, newDate: newDate, dryRun: true)
            if let error = preview.error {
                actionNotice = error
                return
            }
            movePreview = MovePreview(
                id: taskId,
                taskId: taskId,
                taskTitle: taskTitle,
                newDate: newDate,
                changes: preview.changes
            )
        } catch {
            actionNotice = error.localizedDescription
        }
    }

    func confirmMove() async {
        guard let preview = movePreview else { return }
        let taskId = preview.taskId
        busyTaskIds.insert(taskId)
        defer { busyTaskIds.remove(taskId) }
        do {
            let result = try await cli.move(taskId: taskId, newDate: preview.newDate, dryRun: false)
            movePreview = nil
            if let error = result.error {
                actionNotice = error
                return
            }
            if let calErrors = result.calendarErrors, !calErrors.isEmpty {
                actionNotice = "任务已移动；部分日历同步失败。"
            }
            await loadToday()
        } catch {
            actionNotice = error.localizedDescription
        }
    }

    func cancelMovePreview() {
        movePreview = nil
    }

    static func tomorrowISO() -> String {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
        return Self.isoDate(tomorrow)
    }

    static func isoDate(_ date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
