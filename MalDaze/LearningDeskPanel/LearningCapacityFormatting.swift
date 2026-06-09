import Foundation

enum LearningCapacityFormatting {
    static func hours(fromMinutes minutes: Int) -> Double {
        Double(minutes) / 60.0
    }

    static func minutes(fromHours hours: Double) -> Int {
        Int((hours * 60.0).rounded())
    }

    static func formatHours(fromMinutes minutes: Int) -> String {
        formatHours(hours(fromMinutes: minutes))
    }

    static func formatHours(_ hours: Double) -> String {
        let rounded = (hours * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f 小时", rounded)
        }
        return String(format: "%.1f 小时", rounded)
    }

    static func formatLoad(totalMinutes: Int, budgetMinutes: Int) -> String {
        "\(formatHours(fromMinutes: totalMinutes)) / \(formatHours(fromMinutes: budgetMinutes))"
    }

    static func formatMinutesLoad(totalMinutes: Int, budgetMinutes: Int) -> String {
        "\(totalMinutes) 分钟 / \(budgetMinutes) 分钟"
    }

    static func progressFraction(done: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(done) / Double(total)
    }
}
