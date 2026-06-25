import Foundation
import Security

enum ProviderAPIKeySecureStore {
    static let service = "com.maldaze.provider-api-key"

    private static var inMemoryStore: [LLMProviderID: String]?

    static func activateInMemoryStoreForTesting() {
        inMemoryStore = [:]
    }

    static func deactivateInMemoryStoreForTesting() {
        inMemoryStore = nil
    }

    static func read(for provider: LLMProviderID) -> String? {
        if let store = inMemoryStore {
            return store[provider]
        }
        var query = baseQuery(for: provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return status == errSecItemNotFound ? nil : nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, for provider: LLMProviderID) {
        if inMemoryStore != nil {
            inMemoryStore?[provider] = value
            return
        }
        let data = Data(value.utf8)
        var query = baseQuery(for: provider)
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus == errSecItemNotFound {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    static func delete(for provider: LLMProviderID) {
        if inMemoryStore != nil {
            inMemoryStore?.removeValue(forKey: provider)
            return
        }
        SecItemDelete(baseQuery(for: provider) as CFDictionary)
    }

    static func legacyUserDefaultsKeys(for provider: LLMProviderID) -> [String] {
        switch provider {
        case .gemini:
            return [MalDazeDefaults.smartInputGeminiAPIKey, MalDazeDefaults.geminiAPIKey]
        case .openai:
            return [MalDazeDefaults.smartInputOpenAIAPIKey]
        case .deepseek:
            return [MalDazeDefaults.smartInputDeepSeekAPIKey]
        }
    }

    static func migrateFromUserDefaultsIfNeeded(defaults: UserDefaults = .standard) {
        for provider in LLMProviderID.allCases {
            migrateProviderIfNeeded(provider, defaults: defaults)
        }
    }

    private static func migrateProviderIfNeeded(_ provider: LLMProviderID, defaults: UserDefaults) {
        if let existing = read(for: provider), !existing.isEmpty {
            clearLegacyUserDefaultsKeys(for: provider, defaults: defaults)
            return
        }
        for key in legacyUserDefaultsKeys(for: provider) {
            guard defaults.object(forKey: key) != nil else { continue }
            let value = defaults.string(forKey: key)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            write(value, for: provider)
            defaults.removeObject(forKey: key)
            return
        }
    }

    private static func clearLegacyUserDefaultsKeys(for provider: LLMProviderID, defaults: UserDefaults) {
        for key in legacyUserDefaultsKeys(for: provider) {
            defaults.removeObject(forKey: key)
        }
    }

    private static func baseQuery(for provider: LLMProviderID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
    }
}
