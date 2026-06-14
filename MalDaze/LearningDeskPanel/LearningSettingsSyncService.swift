import Foundation

protocol LearningCapacityProfileStoring {
    func readDailyCapacityMinutes() -> Int?
    func writeDailyCapacityMinutes(_ minutes: Int) throws
}

struct LearningSettingsSyncService {
    static let dailyCapacityHoursKey = MalDazeDefaultsKeys.Learning.dailyCapacityHours
    static let defaultDailyCapacityHours = 5.0
    static let dailyCapacityHoursMin = 1.0
    static let dailyCapacityHoursMax = 12.0

    let defaults: UserDefaults
    let profileStore: LearningCapacityProfileStoring

    init(
        defaults: UserDefaults = .standard,
        profileStore: LearningCapacityProfileStoring = HermesLearningProfileStore()
    ) {
        self.defaults = defaults
        self.profileStore = profileStore
    }

    static func clampedDailyCapacityHours(_ hours: Double) -> Double {
        let base = hours == 0 ? defaultDailyCapacityHours : hours
        return min(max(base, dailyCapacityHoursMin), dailyCapacityHoursMax)
    }

    func resolvedDailyCapacityHours() -> Double {
        migrateDailyCapacityIfNeeded()
        return Self.clampedDailyCapacityHours(defaults.double(forKey: Self.dailyCapacityHoursKey))
    }

    func resolvedDailyCapacityMinutes() -> Int {
        LearningCapacityFormatting.minutes(fromHours: resolvedDailyCapacityHours())
    }

    func migrateDailyCapacityIfNeeded() {
        guard defaults.object(forKey: Self.dailyCapacityHoursKey) == nil else { return }
        defaults.set(Self.defaultDailyCapacityHours, forKey: Self.dailyCapacityHoursKey)
        syncDailyCapacityToHermesProfile()
    }

    func syncDailyCapacityToHermesProfile() {
        let minutes = resolvedDailyCapacityMinutes()
        try? profileStore.writeDailyCapacityMinutes(minutes)
    }

    func ensureDailyCapacitySyncedToHermes() {
        migrateDailyCapacityIfNeeded()
        let target = resolvedDailyCapacityMinutes()
        if profileStore.readDailyCapacityMinutes() != target {
            syncDailyCapacityToHermesProfile()
        }
    }
}
