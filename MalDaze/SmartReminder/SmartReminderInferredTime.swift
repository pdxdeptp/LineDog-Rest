import Foundation

/// 当 JSON 未给出 `hour`/`minute` 时，根据标题、备注与用户原文推断墙钟时刻（与 `alarm_date` 的日期组合）。
enum SmartReminderInferredTime {
    static func inferHourMinute(title: String, notes: String?, rawUserInput: String) -> (hour: Int, minute: Int) {
        let blob = [title, notes ?? "", rawUserInput]
            .joined(separator: " ")
            .lowercased()

        func has(_ needles: String...) -> Bool {
            needles.contains { blob.contains($0.lowercased()) }
        }

        // 更具体的短语优先
        if has("面试", "interview") { return (14, 0) }
        if has("presentation") { return (14, 0) }
        if has("会议", "开会", "例会", "seminar", "standup", "站会") { return (10, 0) }
        if has("ddl", "deadline", "截止", "交作业", "due") { return (21, 0) }
        if has("作业", "homework", "assignment", "reflection", "论文", "考试", "课程", "课", "reading") {
            return (21, 0)
        }
        if has("吃药", "服药", "medication") { return (9, 0) }
        if has("早饭", "早餐", "起床") { return (8, 0) }
        if has("午饭", "午餐", "中午", "午休") { return (12, 30) }
        if has("晚饭", "晚餐", "夜宵") { return (19, 0) }
        if has("通勤", "上班", "打卡") { return (8, 30) }
        if has("运动", "跑步", "健身", "gym", "锻炼", "瑜伽") { return (18, 0) }
        if has("睡觉", "sleep", "bed", "入睡") { return (22, 30) }
        if has("洗碗", "倒垃圾", "遛狗", "浇花", "打扫", "收衣服", "晾衣服") { return (19, 0) }
        if has("取快递", "快递") { return (18, 0) }
        if has("邮件", "email", "发信") { return (10, 0) }
        if has("电话", "打电话", "phone call") { return (15, 0) }

        // 泛化：未命中时用「下班前后」比深夜更自然
        return (18, 0)
    }
}
