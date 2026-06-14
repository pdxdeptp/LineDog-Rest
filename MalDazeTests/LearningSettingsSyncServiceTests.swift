import XCTest
@testable import MalDaze

final class LearningSettingsSyncServiceTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        for suiteName in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    func testMissingDefaultsMigrationWritesDefaultHoursAndSyncsProfile() {
        let defaults = makeDefaults()
        let store = FakeLearningCapacityProfileStore()
        let service = LearningSettingsSyncService(defaults: defaults, profileStore: store)

        service.migrateDailyCapacityIfNeeded()

        XCTAssertEqual(defaults.double(forKey: MalDazeDefaults.learningDailyCapacityHours), 5.0)
        XCTAssertEqual(store.writtenMinutes, [300])
    }

    func testExistingDefaultsAreNotOverwrittenByMigration() {
        let defaults = makeDefaults()
        defaults.set(7.5, forKey: MalDazeDefaults.learningDailyCapacityHours)
        let store = FakeLearningCapacityProfileStore()
        let service = LearningSettingsSyncService(defaults: defaults, profileStore: store)

        service.migrateDailyCapacityIfNeeded()

        XCTAssertEqual(defaults.double(forKey: MalDazeDefaults.learningDailyCapacityHours), 7.5)
        XCTAssertTrue(store.writtenMinutes.isEmpty)
    }

    func testSyncClampsStoredHoursAndWritesRoundedMinutes() {
        let defaults = makeDefaults()
        defaults.set(12.8, forKey: MalDazeDefaults.learningDailyCapacityHours)
        let store = FakeLearningCapacityProfileStore()
        let service = LearningSettingsSyncService(defaults: defaults, profileStore: store)

        service.syncDailyCapacityToHermesProfile()

        XCTAssertEqual(store.writtenMinutes, [720])
    }

    func testEnsureWritesWhenProfileMissingOrStaleAndAvoidsDuplicateWriteWhenEqual() {
        let defaults = makeDefaults()
        defaults.set(6.5, forKey: MalDazeDefaults.learningDailyCapacityHours)
        let missingStore = FakeLearningCapacityProfileStore()
        let missingService = LearningSettingsSyncService(defaults: defaults, profileStore: missingStore)

        missingService.ensureDailyCapacitySyncedToHermes()

        XCTAssertEqual(missingStore.writtenMinutes, [390])

        let staleStore = FakeLearningCapacityProfileStore(initialMinutes: 90)
        let staleService = LearningSettingsSyncService(defaults: defaults, profileStore: staleStore)

        staleService.ensureDailyCapacitySyncedToHermes()

        XCTAssertEqual(staleStore.writtenMinutes, [390])

        let equalStore = FakeLearningCapacityProfileStore(initialMinutes: 390)
        let equalService = LearningSettingsSyncService(defaults: defaults, profileStore: equalStore)

        equalService.ensureDailyCapacitySyncedToHermes()

        XCTAssertTrue(equalStore.writtenMinutes.isEmpty)
    }

    func testWriteErrorsAreSwallowed() {
        let defaults = makeDefaults()
        defaults.set(4.0, forKey: MalDazeDefaults.learningDailyCapacityHours)
        let store = FakeLearningCapacityProfileStore(throwsOnWrite: true)
        let service = LearningSettingsSyncService(defaults: defaults, profileStore: store)

        XCTAssertNoThrow(service.syncDailyCapacityToHermesProfile())
        XCTAssertNoThrow(service.ensureDailyCapacitySyncedToHermes())
    }

    func testSourceGuardMovesHermesProfileWritesOutOfMalDazeDefaultsAndIntoAppTarget() throws {
        let root = projectRootURL()
        let defaultsSource = try String(contentsOf: root.appendingPathComponent("MalDaze/MalDazeDefaults.swift"))
        let projectSource = try String(contentsOf: root.appendingPathComponent("MalDaze.xcodeproj/project.pbxproj"))

        XCTAssertFalse(defaultsSource.contains("HermesLearningProfileStore()"))
        XCTAssertFalse(defaultsSource.contains("writeDailyCapacityMinutes"))
        XCTAssertTrue(projectSource.contains("LearningSettingsSyncService.swift in Sources"))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "LearningSettingsSyncServiceTests-\(UUID().uuidString)"
        suiteNames.append(suiteName)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.setVolatileDomain([:], forName: "NSRegistrationDomain")
        return defaults
    }

    private func projectRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private final class FakeLearningCapacityProfileStore: LearningCapacityProfileStoring {
    private var storedMinutes: Int?
    private let throwsOnWrite: Bool
    private(set) var writtenMinutes: [Int] = []

    init(initialMinutes: Int? = nil, throwsOnWrite: Bool = false) {
        storedMinutes = initialMinutes
        self.throwsOnWrite = throwsOnWrite
    }

    func readDailyCapacityMinutes() -> Int? {
        storedMinutes
    }

    func writeDailyCapacityMinutes(_ minutes: Int) throws {
        if throwsOnWrite {
            throw WriteError.failed
        }
        writtenMinutes.append(minutes)
        storedMinutes = minutes
    }

    private enum WriteError: Error {
        case failed
    }
}
