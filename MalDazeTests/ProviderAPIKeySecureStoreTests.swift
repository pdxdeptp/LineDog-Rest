import XCTest
@testable import MalDaze

final class ProviderAPIKeySecureStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ProviderAPIKeySecureStore.activateInMemoryStoreForTesting()
    }

    override func tearDown() {
        ProviderAPIKeySecureStore.deactivateInMemoryStoreForTesting()
        super.tearDown()
    }

    func testWriteAndReadRoundTrip() {
        ProviderAPIKeySecureStore.write("secret-openai", for: .openai)
        XCTAssertEqual(ProviderAPIKeySecureStore.read(for: .openai), "secret-openai")
    }

    func testMigrateFromUserDefaultsRemovesLegacyKey() {
        let suiteName = "MalDaze.tests.providerKeyMigrate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("legacy-deepseek", forKey: MalDazeDefaults.smartInputDeepSeekAPIKey)
        ProviderAPIKeySecureStore.migrateFromUserDefaultsIfNeeded(defaults: defaults)

        XCTAssertEqual(ProviderAPIKeySecureStore.read(for: .deepseek), "legacy-deepseek")
        XCTAssertNil(defaults.object(forKey: MalDazeDefaults.smartInputDeepSeekAPIKey))
    }

    func testMalDazeDefaultsSetSmartInputAPIKeyUsesSecureStore() {
        let suiteName = "MalDaze.tests.providerKeyDefaults.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        MalDazeDefaults.setSmartInputAPIKey("gemini-key", for: .gemini, defaults: defaults)
        XCTAssertEqual(MalDazeDefaults.resolvedSmartInputAPIKey(for: .gemini, defaults: defaults), "gemini-key")
        XCTAssertNil(defaults.object(forKey: MalDazeDefaults.smartInputGeminiAPIKey))
    }
}
