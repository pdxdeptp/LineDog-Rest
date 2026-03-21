import Foundation

/// 写入 `EKReminder.notes` 的日常标记（PRD Tag Hack）。
enum LineDogRoutineTag {
    static let marker = "#日常"

    static func notesContainRoutineMarker(_ notes: String?) -> Bool {
        (notes ?? "").contains(marker)
    }
}

/// 合并模型 `is_routine` 与用户原文，减少漏标日常（模型 camelCase、家务误判等）。
enum SmartReminderRoutineInference {
    /// 常见家务/习惯短语；仅当模型未标日常时作为保守补全。
    private static let choreHints: [String] = [
        "收衣服", "晾衣服", "洗衣服", "晒衣服",
        "洗碗", "倒垃圾", "遛狗", "吃药", "浇花",
        "打扫卫生", "整理房间", "叠衣服", "铲屎"
    ]

    static func effectiveIsRoutine(llm: Bool, rawUserInput: String, reminderTitle: String) -> Bool {
        if llm { return true }
        let combined = rawUserInput + reminderTitle
        if combined.contains(LineDogRoutineTag.marker) { return true }
        for hint in choreHints {
            if rawUserInput.contains(hint) || reminderTitle.contains(hint) {
                return true
            }
        }
        return false
    }
}

enum SmartReminderNotesComposer {
    /// `isRoutine == true` 时在末尾追加 `#日常`（已有则不重复）。
    static func finalizedNotes(llmNotes: String?, isRoutine: Bool) -> String? {
        guard isRoutine else { return llmNotes }
        guard let raw = llmNotes, !raw.isEmpty else {
            return LineDogRoutineTag.marker
        }
        if LineDogRoutineTag.notesContainRoutineMarker(raw) {
            return llmNotes
        }
        return raw + "\n" + LineDogRoutineTag.marker
    }
}
