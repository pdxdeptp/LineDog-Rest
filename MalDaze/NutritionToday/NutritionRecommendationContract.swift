import Foundation

struct NutritionRecommendationSource: Equatable, Codable {
    let kind: String
    let channel: String?
}

struct NutritionRecommendationBasis: Equatable, Codable {
    let dailyLogDate: String
    let dailyLogPanelUpdatedAt: String
    let recordsCount: Int
}

enum NutritionRecommendationSnapshotState: String, Equatable, Codable {
    case available
    case unavailable
}

struct NutritionRecommendationItem: Equatable, Codable, Identifiable {
    let displayName: String
    let name: String?
    let grams: Double?
    let kcal: Double?
    let loggable: Bool
    private let occurrenceID: String?

    var id: String {
        occurrenceID ?? contentID
    }

    private var contentID: String {
        let gramsText = grams.map { String($0) } ?? ""
        let kcalText = kcal.map { String($0) } ?? ""
        return "\(displayName)|\(name ?? "")|\(gramsText)|\(kcalText)|\(loggable)"
    }

    enum CodingKeys: String, CodingKey {
        case displayName, name, grams, kcal, loggable
    }

    init(
        displayName: String,
        name: String?,
        grams: Double?,
        kcal: Double? = nil,
        loggable: Bool
    ) {
        self.init(
            displayName: displayName,
            name: name,
            grams: grams,
            kcal: kcal,
            loggable: loggable,
            occurrenceID: nil
        )
    }

    private init(
        displayName: String,
        name: String?,
        grams: Double?,
        kcal: Double?,
        loggable: Bool,
        occurrenceID: String?
    ) {
        self.displayName = displayName
        self.name = name
        self.grams = grams
        self.kcal = kcal
        self.loggable = loggable
        self.occurrenceID = occurrenceID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            displayName: try c.decode(String.self, forKey: .displayName),
            name: try c.decodeIfPresent(String.self, forKey: .name),
            grams: try c.decodeIfPresent(Double.self, forKey: .grams),
            kcal: try c.decodeIfPresent(Double.self, forKey: .kcal),
            loggable: try c.decode(Bool.self, forKey: .loggable)
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(displayName, forKey: .displayName)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(grams, forKey: .grams)
        try c.encodeIfPresent(kcal, forKey: .kcal)
        try c.encode(loggable, forKey: .loggable)
    }

    func identified(suggestionLabel: String, suggestionRationale: String?, occurrenceIndex: Int) -> NutritionRecommendationItem {
        NutritionRecommendationItem(
            displayName: displayName,
            name: name,
            grams: grams,
            kcal: kcal,
            loggable: loggable,
            occurrenceID: "\(suggestionLabel)|\(suggestionRationale ?? "")|\(occurrenceIndex)|\(contentID)"
        )
    }
}

struct NutritionRecommendationSuggestion: Equatable, Codable, Identifiable {
    let label: String
    let rationale: String?
    let items: [NutritionRecommendationItem]
    let warnings: [String]

    var id: String {
        "\(label)|\(rationale ?? "")|\(items.map(\.id).joined(separator: ";"))"
    }

    enum CodingKeys: String, CodingKey {
        case label, rationale, items, warnings
    }

    init(
        label: String,
        rationale: String?,
        items: [NutritionRecommendationItem],
        warnings: [String]
    ) {
        self.label = label
        self.rationale = rationale
        self.items = Self.identifiedItems(items, label: label, rationale: rationale)
        self.warnings = warnings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        rationale = try c.decodeIfPresent(String.self, forKey: .rationale)
        items = Self.identifiedItems(
            try c.decode([NutritionRecommendationItem].self, forKey: .items),
            label: label,
            rationale: rationale
        )
        warnings = try c.decodeIfPresent([String].self, forKey: .warnings) ?? []
    }

    private static func identifiedItems(
        _ items: [NutritionRecommendationItem],
        label: String,
        rationale: String?
    ) -> [NutritionRecommendationItem] {
        items.enumerated().map { offset, item in
            item.identified(
                suggestionLabel: label,
                suggestionRationale: rationale,
                occurrenceIndex: offset
            )
        }
    }
}

struct NutritionRecommendationSnapshot: Equatable, Codable {
    let schemaVersion: Int
    let date: String
    let generatedAt: String
    let source: NutritionRecommendationSource
    let basedOn: NutritionRecommendationBasis
    let state: NutritionRecommendationSnapshotState
    let summary: String
    let suggestions: [NutritionRecommendationSuggestion]
}

enum NutritionRecommendationContractError: Error, Equatable {
    case fileNotFound
    case readFailed
    case invalidJSON
    case unsupportedSchema(Int)
}

protocol NutritionRecommendationReading {
    var fileURL: URL { get }
    func read() throws -> NutritionRecommendationSnapshot
}

struct NutritionRecommendationContractReader: NutritionRecommendationReading {
    let fileURL: URL

    static var defaultHermesFileURL: URL {
        HermesRuntimePaths().nutritionRecommendationFileURL
    }

    init(fileURL: URL = NutritionRecommendationContractReader.defaultHermesFileURL) {
        self.fileURL = fileURL
    }

    func read() throws -> NutritionRecommendationSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NutritionRecommendationContractError.fileNotFound
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw NutritionRecommendationContractError.readFailed
        }

        let snapshot: NutritionRecommendationSnapshot
        do {
            snapshot = try JSONDecoder().decode(NutritionRecommendationSnapshot.self, from: data)
        } catch {
            throw NutritionRecommendationContractError.invalidJSON
        }

        guard snapshot.schemaVersion == 1 else {
            throw NutritionRecommendationContractError.unsupportedSchema(snapshot.schemaVersion)
        }
        guard Self.isValid(snapshot) else {
            throw NutritionRecommendationContractError.invalidJSON
        }
        return snapshot
    }

    static func userFacingMessage(for error: NutritionRecommendationContractError) -> String {
        switch error {
        case .fileNotFound:
            return "等待 Hermes 写入饮食建议。"
        case .readFailed:
            return "无法读取 recommendation.json。"
        case .invalidJSON:
            return "recommendation.json 格式无效。"
        case .unsupportedSchema(let version):
            return "不支持的 recommendation 契约版本：\(version)。"
        }
    }

    private static func isValid(_ snapshot: NutritionRecommendationSnapshot) -> Bool {
        guard !snapshot.date.isEmpty,
              !snapshot.generatedAt.isEmpty,
              !snapshot.basedOn.dailyLogDate.isEmpty,
              !snapshot.basedOn.dailyLogPanelUpdatedAt.isEmpty,
              !snapshot.summary.isEmpty
        else { return false }

        for suggestion in snapshot.suggestions {
            guard !suggestion.label.isEmpty else { return false }
            for item in suggestion.items {
                guard !item.displayName.isEmpty else { return false }
                if let kcal = item.kcal, kcal < 0 { return false }
                if item.loggable {
                    guard let name = item.name, !name.isEmpty,
                          let grams = item.grams, grams > 0
                    else { return false }
                }
            }
        }
        return true
    }
}
