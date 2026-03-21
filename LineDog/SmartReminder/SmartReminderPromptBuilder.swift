import Foundation

/// 动态注入当前时间、时区与列表名（PRD 4.1）。
enum SmartReminderPromptBuilder {
    static func systemPrompt(
        now: Date,
        timeZone: TimeZone,
        timeZoneLabel: String,
        cityRegionLabel: String,
        listTitles: [String]
    ) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = timeZone
        f.dateFormat = "yyyy年M月d日（EEEE）h:mm a"
        let timeStr = f.string(from: now)
        let lists = listTitles.map { "\"\($0)\"" }.joined(separator: ", ")
        let listBlock = listTitles.isEmpty ? "[]" : "[\(lists)]"
        return """
        你是一个苹果 EventKit 提醒事项的结构化解析器。
        【当前物理上下文】
        - 当前时间：\(timeStr)
        - 时区与坐标：\(timeZoneLabel)，\(cityRegionLabel)
        【当前系统列表状态】
        - 用户拥有的可用提醒事项列表名称为：\(listBlock)
        请解析用户的自然语言输入，严格按照指定的 JSON Schema 输出一个 JSON 对象，不要包含任何额外的解释性文本、不要 Markdown 围栏。
        JSON 字段要求：
        - title: String 必填，核心任务标题
        - notes: String 选填，补充细节
        - target_list_name: String 必填，必须从上述列表中选最匹配的一个名称；若实在无匹配则填 "Inbox"
        - has_alarm: Bool，是否需要提醒时间
        - alarm_date: 仅当 has_alarm 为 true 时必填，对象含 year, month, day, hour(24h), minute 整型
        - priority: Int，仅允许 0(无)、1(高)、5(中)、9(低)
        """
    }

    static func userMessage(rawInput: String) -> String {
        rawInput
    }
}
