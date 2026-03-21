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
        JSON 字段要求（键名必须严格使用下划线 snake_case：is_routine、target_list_name、has_alarm、alarm_date，禁止使用 camelCase）：
        - title: String 必填，核心任务标题
        - is_routine: Bool 必填。日常类（true）：生活中反复出现的维护/习惯，例如吃药、通勤、运动后整理、收晾衣服、洗碗、倒垃圾、遛狗、浇花、打扫卫生等；即使用户只说「一小时后…」这种单次闹钟，只要任务本身是家务/习惯性质，仍标 true。非日常（false）：有明确截止的一次性事务（赶 DDL、某日前退款、单次会议、一次性取快递等）。
        - notes: String 选填，补充细节（日常任务写入后 Swift 会在备注追加 #日常 标签，你无需自行输出该标签）
        - target_list_name: String 必填，必须从上述列表中选最匹配的一个名称；若实在无匹配则填 "Inbox"
        - has_alarm: Bool。非日常任务：仅当用户明确表达要到点提醒/通知/闹钟（如「记得叫我」「到时提醒我」）时为 true；未提则为 false。日常任务：此字段可忽略，客户端会对有 alarm_date 的日常默认打开到点提醒。
        - alarm_date: 任务对应的日期时间（截止日期与提醒时间同源）。**必须**使用 JSON 对象格式：{"year":2026,"month":3,"day":21,"hour":19,"minute":10}（hour 为 24 小时制），**禁止**输出 ISO8601 字符串。无具体时间可省略或 null。非日常且 has_alarm 为 false 时仍可填 alarm_date 表示仅截止日期、不要到点闹钟。
        - priority: Int，仅允许 0(无)、1(高)、5(中)、9(低)
        """
    }

    static func userMessage(rawInput: String) -> String {
        rawInput
    }
}
