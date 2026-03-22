import Foundation

/// 设置里可选的 Gemini 模型与解析到 API 用的 ID。
enum LineDogGeminiModelCatalog {
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
            defaults.string(forKey: LineDogDefaults.geminiModelId)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty { return LineDogDefaults.defaultGeminiModelId }
        if raw.contains("/") || raw.contains(":") { return LineDogDefaults.defaultGeminiModelId }
        return raw
    }
}
