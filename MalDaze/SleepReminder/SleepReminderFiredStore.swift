import Foundation

/// 已触发事件 id 持久化，按 Hermes `updatedAt` 分桶，避免重读 JSON 后重复响铃。
struct SleepReminderFiredStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadFiredIDs(for contractUpdatedAt: String) -> Set<String> {
        guard defaults.string(forKey: MalDazeDefaults.sleepScheduleFiredContractUpdatedAt) == contractUpdatedAt else {
            return []
        }
        let raw = defaults.stringArray(forKey: MalDazeDefaults.sleepScheduleFiredEventIDs) ?? []
        return Set(raw)
    }

    func save(firedIDs: Set<String>, contractUpdatedAt: String) {
        defaults.set(contractUpdatedAt, forKey: MalDazeDefaults.sleepScheduleFiredContractUpdatedAt)
        defaults.set(Array(firedIDs).sorted(), forKey: MalDazeDefaults.sleepScheduleFiredEventIDs)
    }

    func clear() {
        defaults.removeObject(forKey: MalDazeDefaults.sleepScheduleFiredContractUpdatedAt)
        defaults.removeObject(forKey: MalDazeDefaults.sleepScheduleFiredEventIDs)
    }
}
