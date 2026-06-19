import Foundation

struct NutritionMacroBucket: Equatable, Codable {
    let kcal: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let sodiumMg: Double

    enum CodingKeys: String, CodingKey {
        case kcal
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case sodiumMg = "sodium_mg"
    }
}

struct NutritionPanelSuggestionItem: Equatable, Codable {
    let name: String
    let grams: Double
    let kcal: Double?
    let proteinG: Double?
    let carbsG: Double?
    let fatG: Double?
    let sodiumMg: Double?

    enum CodingKeys: String, CodingKey {
        case name, grams, kcal
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case sodiumMg = "sodium_mg"
    }
}

struct NutritionTargetBreakdownLayer: Equatable, Codable {
    let id: String
    let label: String
    let detail: String?
    let kcal: Double?
    let resultKcal: Double?
    let children: [NutritionTargetBreakdownLayer]?

    init(
        id: String,
        label: String,
        detail: String? = nil,
        kcal: Double? = nil,
        resultKcal: Double? = nil,
        children: [NutritionTargetBreakdownLayer]? = nil
    ) {
        self.id = id
        self.label = label
        self.detail = detail
        self.kcal = kcal
        self.resultKcal = resultKcal
        self.children = children
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
        kcal = try c.decodeIfPresent(Double.self, forKey: .kcal)
        resultKcal = try c.decodeIfPresent(Double.self, forKey: .resultKcal)
        children = try c.decodeIfPresent([NutritionTargetBreakdownLayer].self, forKey: .children)
    }
}

struct NutritionTargetMacroRules: Equatable, Codable {
    let proteinGPerKg: Double
    let fatGPerKg: Double
    let note: String?
}

struct NutritionTargetBreakdown: Equatable, Codable {
    let targetKcal: Int
    let phaseLabel: String?
    let weightTrendKg: Double?
    let weightTrendDays: Int?
    let layers: [NutritionTargetBreakdownLayer]
    let macroRules: NutritionTargetMacroRules?
}

struct NutritionPanelSuggestion: Equatable, Codable {
    let label: String?
    let items: [NutritionPanelSuggestionItem]
    let total: NutritionMacroBucket?
    let withinSlack: Bool?

    enum CodingKeys: String, CodingKey {
        case label, items, total
        case withinSlack = "within_slack"
    }
}

struct NutritionPanel: Equatable, Codable {
    let schemaVersion: Int
    let updatedAt: String
    let dayLabel: String
    /// 训练日部位文案（如「练胸」「练背和腿」）；休息日无此字段。
    let workoutLabel: String?
    let targets: NutritionMacroBucket
    let consumed: NutritionMacroBucket
    let remaining: NutritionMacroBucket
    let suggestions: [NutritionPanelSuggestion]
    let calorieSlack: Int
    let targetBreakdown: NutritionTargetBreakdown?

    enum CodingKeys: String, CodingKey {
        case schemaVersion, updatedAt, dayLabel, workoutLabel, targets, consumed, remaining, suggestions, calorieSlack, targetBreakdown
    }

    init(
        schemaVersion: Int,
        updatedAt: String,
        dayLabel: String,
        workoutLabel: String? = nil,
        targets: NutritionMacroBucket,
        consumed: NutritionMacroBucket,
        remaining: NutritionMacroBucket,
        suggestions: [NutritionPanelSuggestion],
        calorieSlack: Int,
        targetBreakdown: NutritionTargetBreakdown? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.dayLabel = dayLabel
        self.workoutLabel = workoutLabel
        self.targets = targets
        self.consumed = consumed
        self.remaining = remaining
        self.suggestions = suggestions
        self.calorieSlack = calorieSlack
        self.targetBreakdown = targetBreakdown
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        updatedAt = try c.decode(String.self, forKey: .updatedAt)
        dayLabel = try c.decode(String.self, forKey: .dayLabel)
        workoutLabel = try c.decodeIfPresent(String.self, forKey: .workoutLabel)
        targets = try c.decode(NutritionMacroBucket.self, forKey: .targets)
        consumed = try c.decode(NutritionMacroBucket.self, forKey: .consumed)
        remaining = try c.decode(NutritionMacroBucket.self, forKey: .remaining)
        suggestions = try c.decodeIfPresent([NutritionPanelSuggestion].self, forKey: .suggestions) ?? []
        calorieSlack = try c.decodeIfPresent(Int.self, forKey: .calorieSlack) ?? 50
        targetBreakdown = try c.decodeIfPresent(NutritionTargetBreakdown.self, forKey: .targetBreakdown)
    }
}

struct NutritionDailyRecord: Equatable, Codable {
    let name: String
    let kcal: Double?
    let proteinG: Double?
    let carbsG: Double?
    let fatG: Double?
    let sodiumMg: Double?
    let weightG: Double?

    enum CodingKeys: String, CodingKey {
        case name, kcal
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case sodiumMg = "sodium_mg"
        case weightG = "weight_g"
    }
}

struct NutritionDailyLog: Equatable {
    let date: String
    let dayType: String
    let records: [NutritionDailyRecord]
    let panel: NutritionPanel?
}

enum NutritionDailyLogContractError: Error, Equatable {
    case fileNotFound
    case readFailed
    case invalidJSON
    case unsupportedPanelSchema(Int)
}

protocol NutritionDailyLogReading {
    var fileURL: URL { get }
    func read() throws -> NutritionDailyLog
}

struct NutritionDailyLogContractReader: NutritionDailyLogReading {
    let fileURL: URL

    static var defaultHermesFileURL: URL {
        HermesRuntimePaths().nutritionDailyLogFileURL
    }

    init(fileURL: URL = NutritionDailyLogContractReader.defaultHermesFileURL) {
        self.fileURL = fileURL
    }

    func read() throws -> NutritionDailyLog {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NutritionDailyLogContractError.fileNotFound
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw NutritionDailyLogContractError.readFailed
        }

        let decoder = JSONDecoder()
        guard let root = try? decoder.decode(Root.self, from: data) else {
            throw NutritionDailyLogContractError.invalidJSON
        }

        if let panel = root.panel, panel.schemaVersion != 1 {
            throw NutritionDailyLogContractError.unsupportedPanelSchema(panel.schemaVersion)
        }

        return NutritionDailyLog(
            date: root.date,
            dayType: root.dayType,
            records: root.records,
            panel: root.panel
        )
    }

    static func userFacingMessage(for error: NutritionDailyLogContractError) -> String {
        switch error {
        case .fileNotFound:
            return "未找到 Hermes 营养日志，请确认 ~/.hermes/data/nutrition 存在。"
        case .readFailed:
            return "无法读取 daily_log.json。"
        case .invalidJSON:
            return "daily_log.json 格式无效。"
        case .unsupportedPanelSchema(let version):
            return "不支持的 panel 契约版本：\(version)。"
        }
    }

    private struct Root: Decodable {
        let date: String
        let dayType: String
        let records: [NutritionDailyRecord]
        let panel: NutritionPanel?

        enum CodingKeys: String, CodingKey {
            case date, records, panel
            case dayType = "day_type"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
            dayType = try c.decodeIfPresent(String.self, forKey: .dayType) ?? "rest"
            records = try c.decodeIfPresent([NutritionDailyRecord].self, forKey: .records) ?? []
            panel = try c.decodeIfPresent(NutritionPanel.self, forKey: .panel)
        }
    }
}

struct NutritionLoggableItem: Equatable, Identifiable {
    let flatIndex: Int
    let displayName: String
    let name: String
    let grams: Double
    let kcal: Double?
    let suggestionLabel: String?
    let sourceItemID: String?

    var id: String { "\(flatIndex)|\(displayName)|\(name)|\(grams)" }

    static func flattened(from panel: NutritionPanel) -> [NutritionLoggableItem] {
        var items: [NutritionLoggableItem] = []
        var index = 1
        for suggestion in panel.suggestions {
            if suggestion.withinSlack == false {
                continue
            }
            for item in suggestion.items {
                items.append(NutritionLoggableItem(
                    flatIndex: index,
                    displayName: item.name,
                    name: item.name,
                    grams: item.grams,
                    kcal: item.kcal,
                    suggestionLabel: suggestion.label,
                    sourceItemID: nil
                ))
                index += 1
            }
        }
        return items
    }

    static func flattened(from snapshot: NutritionRecommendationSnapshot) -> [NutritionLoggableItem] {
        guard snapshot.state == .available else { return [] }

        var items: [NutritionLoggableItem] = []
        var index = 1
        for suggestion in snapshot.suggestions {
            for item in suggestion.items where item.loggable {
                guard let name = item.name, let grams = item.grams else { continue }
                items.append(NutritionLoggableItem(
                    flatIndex: index,
                    displayName: item.displayName,
                    name: name,
                    grams: grams,
                    kcal: item.kcal,
                    suggestionLabel: suggestion.label,
                    sourceItemID: item.id
                ))
                index += 1
            }
        }
        return items
    }
}
