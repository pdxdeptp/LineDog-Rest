import Foundation

enum LLMProviderID: String, CaseIterable, Identifiable, Hashable {
    case gemini
    case openai
    case deepseek

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .openai: return "OpenAI"
        case .deepseek: return "DeepSeek"
        }
    }

    var systemImage: String {
        switch self {
        case .gemini: return "diamond.fill"
        case .openai: return "sparkles"
        case .deepseek: return "brain.head.profile"
        }
    }

    var apiKeyLabel: String {
        "\(displayName) API Key"
    }
}

struct LLMProviderModel: Identifiable, Hashable {
    let id: String
    let label: String
}

enum LLMProviderCatalog {
    struct ProviderOption: Identifiable, Hashable {
        let id: LLMProviderID
        let label: String
    }

    static let providerOptions: [ProviderOption] = LLMProviderID.allCases.map {
        ProviderOption(id: $0, label: $0.displayName)
    }

    static func provider(for rawValue: String) -> LLMProviderID {
        LLMProviderID(rawValue: rawValue) ?? .gemini
    }

    static func models(for provider: LLMProviderID) -> [LLMProviderModel] {
        switch provider {
        case .gemini:
            return [
                LLMProviderModel(id: "gemini-2.5-flash", label: "Gemini 2.5 Flash"),
                LLMProviderModel(id: "gemini-2.5-flash-lite", label: "Gemini 2.5 Flash Lite"),
                LLMProviderModel(id: "gemini-2.5-pro", label: "Gemini 2.5 Pro"),
                LLMProviderModel(id: "gemini-3-flash-preview", label: "Gemini 3 Flash (Preview)"),
                LLMProviderModel(id: "gemini-3.1-flash-lite-preview", label: "Gemini 3.1 Flash Lite (Preview)"),
                LLMProviderModel(id: "gemini-3.1-pro-preview", label: "Gemini 3.1 Pro (Preview)"),
            ]
        case .openai:
            return [
                LLMProviderModel(id: "gpt-5.5", label: "GPT-5.5"),
                LLMProviderModel(id: "gpt-5.4", label: "GPT-5.4"),
                LLMProviderModel(id: "gpt-5.4-mini", label: "GPT-5.4 mini"),
            ]
        case .deepseek:
            return [
                LLMProviderModel(id: "deepseek-v4-pro", label: "DeepSeek V4 Pro"),
                LLMProviderModel(id: "deepseek-v4-flash", label: "DeepSeek V4 Flash"),
            ]
        }
    }

    static func models(for provider: String) -> [LLMProviderModel] {
        models(for: self.provider(for: provider))
    }

    static func defaultModel(for provider: LLMProviderID) -> String {
        models(for: provider)[0].id
    }

    static func defaultModel(for provider: String) -> String {
        defaultModel(for: self.provider(for: provider))
    }
}

enum BackendLLMCatalog {
    typealias Model = LLMProviderModel

    static func models(for provider: String) -> [Model] {
        LLMProviderCatalog.models(for: provider)
    }

    static func defaultModel(for provider: String) -> String {
        LLMProviderCatalog.defaultModel(for: provider)
    }
}

/// 设置里可选的 Gemini 模型与解析到 API 用的 ID。
enum MalDazeGeminiModelCatalog {
    struct Option: Identifiable, Hashable {
        let id: String
        let label: String
    }

    /// 与 Google Gemini API 模型文档（https://ai.google.dev/gemini-api/docs/models）一致（2026-03）。已移除 1.x；2.0 系列官方已标弃用，故不再列入。
    static let pickerOptions: [Option] = [
        Option(id: "gemini-2.5-flash", label: "Gemini 2.5 Flash（默认，稳定）"),
        Option(id: "gemini-2.5-flash-lite", label: "Gemini 2.5 Flash-Lite（更快、更省）"),
        Option(id: "gemini-2.5-pro", label: "Gemini 2.5 Pro（复杂推理）"),
        Option(id: "gemini-3-flash-preview", label: "Gemini 3 Flash（预览）"),
        Option(id: "gemini-3.1-flash-lite-preview", label: "Gemini 3.1 Flash-Lite（预览）"),
        Option(id: "gemini-3.1-pro-preview", label: "Gemini 3.1 Pro（预览）"),
    ]

    /// 读 UserDefaults，供 `GeminiRemindersAPIClient` 每次请求使用（改设置后立即生效）。
    static func modelIdForAPI(defaults: UserDefaults = .standard) -> String {
        let raw =
            defaults.string(forKey: MalDazeDefaults.geminiModelId)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty { return MalDazeDefaults.defaultGeminiModelId }
        if raw.contains("/") || raw.contains(":") { return MalDazeDefaults.defaultGeminiModelId }
        return raw
    }
}
