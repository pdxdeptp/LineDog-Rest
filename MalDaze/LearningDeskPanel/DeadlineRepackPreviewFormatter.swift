import Foundation

enum DeadlineRepackPreviewFormatter {
    static func make(from result: HermesSetDeadlineResponse) -> LearningDeskPanelViewModel.DeadlineRepackPreview {
        LearningDeskPanelViewModel.DeadlineRepackPreview(
            feasible: result.isFeasiblePreview,
            affectedProjectCount: result.affectedProjectIds?.count ?? 0,
            changeCount: result.changes?.count ?? 0,
            overflowCount: result.overflowCount ?? 0,
            cadenceLines: cadenceLines(from: result.projectCadences ?? []),
            conflictSummary: conflictSummary(from: result)
        )
    }

    static func cadenceLines(from cadences: [HermesProjectCadence]) -> [String] {
        cadences.compactMap { cadence in
            guard let remaining = cadence.remainingStudyTasks,
                  let days = cadence.eligibleStudyDays,
                  let minDaily = cadence.minPreferredDaily,
                  let maxDaily = cadence.maxPreferredDaily else {
                return nil
            }
            let moved = cadence.movedTaskCount ?? 0
            let pace: String
            if minDaily == maxDaily {
                pace = "每日约 \(minDaily) 节"
            } else {
                pace = "每日约 \(minDaily)–\(maxDaily) 节"
            }
            return "\(cadence.projectId)：剩余 \(remaining) 节 / \(days) 天，\(pace)，移动 \(moved) 节"
        }
    }

    static func conflictSummary(from result: HermesSetDeadlineResponse) -> String? {
        if result.feasible == false {
            var parts: [String] = []
            if let overflow = result.overflowCount, overflow > 0 {
                parts.append("\(overflow) 节课无法排进截止日")
            }
            if let conflicts = result.capacityConflicts, !conflicts.isEmpty {
                parts.append("\(conflicts.count) 天超出每日学习容量")
            }
            if parts.isEmpty {
                parts.append("当前截止日/容量下无法按理想节奏排开")
            }
            parts.append("请延长截止日或提高每日学习容量")
            return parts.joined(separator: "；")
        }
        if let overflow = result.overflowCount, overflow > 0 {
            return "\(overflow) 节课无法排进新截止日"
        }
        return nil
    }
}
