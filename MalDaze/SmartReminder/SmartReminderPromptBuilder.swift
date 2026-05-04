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
        请解析用户的自然语言输入，严格按照指定的 JSON Schema 输出，不要包含任何额外的解释性文本、不要 Markdown 围栏。**根节点**可以是**单个 JSON 对象**，也可以（当用户一句话里包含**多个彼此独立的待办**时）是**对象数组** `[{...},{...}]`，每个对象的字段要求相同。
        JSON 字段要求（键名必须严格使用下划线 snake_case；禁止使用 camelCase）：
        - title: String 必填，核心任务标题
        - is_routine: Bool 必填。**是否日常只看任务性质，不看是否重复**：日常类（true）仅限生活维护与个人习惯——吃药、通勤、运动后整理、收晾衣服、洗碗、倒垃圾、遛狗、浇花、打扫卫生、规律锻炼等；即使用户只说「一小时后…」，只要任务本身是家务/习惯性质，仍标 true。**一律标 false（非日常）**的情况包括：学业与课程相关（作业、reading、reflection、论文、预习复习、考试）、职场交付与项目（报告、会议准备、客户跟进）、以及任何带学分/截止/评分色彩的任务——**即便用户说「每周」「每天」重复做，只要是作业/课业/工作产出，也不是「日常」标签意义上的家务维护。** 非日常还包括：一次性赶 DDL、退款截止、单次会议、单次取快递等。
        - notes: String 选填，补充细节（日常任务写入后 Swift 会在备注追加 #日常 标签，你无需自行输出该标签）
        - target_list_name: String 必填。**用户未点名要放进哪个列表时，一律填 "Reminders"**（不要用 "Inbox" 当默认）。仅当用户**明确说出**与上方列表一致的名称（如 BOSS直聘）时才填该名称；若用户明确说「收件箱」「inbox」「默认列表」等要进系统收件箱，才填 "Inbox"。
        - has_alarm: Bool。非日常任务：仅当用户明确表达要到点提醒/通知/闹钟（如「记得叫我」「到时提醒我」）时为 true；未提则为 false。日常任务：此字段可忽略，客户端会对有 alarm_date 的日常默认打开到点提醒。
        - alarm_date: 任务对应的日期时间（截止日期与提醒时间同源）。**必须**使用 JSON 对象格式：{"year":2026,"month":3,"day":21,"hour":19,"minute":10}（hour 为 24 小时制），**禁止**输出 ISO8601 字符串。非日常且 has_alarm 为 false 时仍可填 alarm_date 表示仅截止日期、不要到点闹钟。若有 **recurrence**，此字段表示**下一次** occurrence 的截止/锚点时间。**时刻规则**：若用户**明确说了**钟点（「下午三点」「晚上8点」「9:30」等），必须输出对应 hour/minute。若用户**只说日期/哪天**而未说钟点，你**必须根据任务性质自行推断**合理的 24 小时制 hour/minute（不要输出 null）：例如会议/seminar/面试→工作时间 10:00 或 14:00；作业/DDL/截止/考试/reading→晚间 21:00；吃药→09:00；三餐相关→对应餐点前后；家务杂事→19:00；运动→18:00；完全泛化事务→18:00。客户端也会在 hour/minute 均为 null 时用同类规则补全，但**优先由你在 JSON 里给出具体数字**。
        - recurrence: 选填对象或 null。仅当用户**明确表达重复**（如「每天」「每周」「每月」「每两周」「每逢周日」）时输出；纯一次性任务填 null 或省略。**学业/工作周期性作业**若用户说了「每周…前交」等，也必须输出 recurrence。**不要**在没有任何重复语义时编造 recurrence。
          - frequency: 必填字符串：none（等同于不重复，可改为省略 recurrence）、daily、weekly、monthly、yearly
          - interval: 选填整数，默认 1；表示每 interval 天/周/月/年（例：每两周 → weekly + interval 2）
          - days_of_week: 选填整数数组，**仅 weekly**；与 Apple EventKit 一致：**1=星期日、2=星期一 … 7=星期六**。例：「每周日晚上」→ [1]；「每个工作日」→ [2,3,4,5,6]
          - day_of_month: 选填整数 1–31，**仅 monthly**（例：「每月15号」→ 15）
        - priority: Int，仅允许 0(无)、1(高)、5(中)、9(低)
        """
    }

    static func userMessage(rawInput: String) -> String {
        rawInput
    }
}
