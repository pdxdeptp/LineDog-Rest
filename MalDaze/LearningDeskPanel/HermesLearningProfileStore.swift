import Foundation

/// 读写 Hermes `profile.json` 中的 `daily_capacity_minutes`（学习日上限 SSOT）。
struct HermesLearningProfileStore {
    let profileURL: URL

    init(hermesHome: URL = ProcessHermesScheduleCLI.defaultHermesHome()) {
        profileURL = hermesHome
            .appendingPathComponent("data/learning-assistant/profile.json", isDirectory: false)
    }

    func readDailyCapacityMinutes() -> Int? {
        guard let data = try? Data(contentsOf: profileURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let minutes = object["daily_capacity_minutes"] as? Int,
              minutes > 0
        else { return nil }
        return minutes
    }

    func writeDailyCapacityMinutes(_ minutes: Int) throws {
        guard minutes > 0 else { return }
        var object: [String: Any] = [:]
        if let data = try? Data(contentsOf: profileURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            object = existing
        }
        object["daily_capacity_minutes"] = minutes
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try FileManager.default.createDirectory(
            at: profileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: profileURL, options: .atomic)
    }
}
