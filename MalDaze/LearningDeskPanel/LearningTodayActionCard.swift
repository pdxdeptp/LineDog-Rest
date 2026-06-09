import SwiftUI

struct LearningTodayActionCard: View {
    let studyOverCapacity: Bool
    let reviewOverCapacity: Bool
    let warnings: [HermesProjectWarning]
    let focusProjectId: String?
    let onFilterProject: (String) -> Void
    let onOpenScheduleTomorrow: () -> Void
    let onOpenProjectsTab: (String) -> Void
    let onRepackProject: (String) -> Void

    private var headline: String {
        var parts: [String] = []
        if studyOverCapacity { parts.append("正课超额") }
        if reviewOverCapacity { parts.append("复习超额") }
        if let first = warnings.first {
            parts.append("\(first.projectName) 落后 \(first.daysBehind) 天")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(headline, systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)

            if warnings.count > 1 {
                ForEach(warnings) { warning in
                    Text("\(warning.projectName) 落后 \(warning.daysBehind) 天")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                if let projectId = focusProjectId ?? warnings.first?.projectId {
                    Button("今日只看项目") {
                        onFilterProject(projectId)
                    }
                    .controlSize(.small)

                    Button("项目 Tab") {
                        onOpenProjectsTab(projectId)
                    }
                    .controlSize(.small)

                    Button("重排未完成课") {
                        onRepackProject(projectId)
                    }
                    .controlSize(.small)
                }

                Button("日程·明天") {
                    onOpenScheduleTomorrow()
                }
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
