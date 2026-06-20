import SwiftUI

struct FocusSessionTodaySection: View {
    let sessionCount: Int
    let totalMinutes: Int
    let finalizedSessions: [FocusSession]
    let inProgress: FocusSessionInProgress?

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var hasFocusActivity: Bool {
        !finalizedSessions.isEmpty || inProgress != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日专注")
                .font(.subheadline.weight(.semibold))

            if !hasFocusActivity {
                Text("今天还没有番茄")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("\(sessionCount) 个番茄 · 共 \(totalMinutes) 分钟")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                VStack(alignment: .leading, spacing: 6) {
                    if let inProgress {
                        inProgressRow(inProgress)
                    }
                    ForEach(finalizedSessions) { session in
                        finalizedRow(session)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.16), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        if !hasFocusActivity {
            return "今日专注，今天还没有番茄"
        }
        return "今日专注，\(sessionCount) 个番茄，共 \(totalMinutes) 分钟"
    }

    @ViewBuilder
    private func inProgressRow(_ segment: FocusSessionInProgress) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(Self.timeFormatter.string(from: segment.startedAt))–进行中 · 已 \(segment.elapsedMinutes) 分钟")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func finalizedRow(_ session: FocusSession) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(
                "\(Self.timeFormatter.string(from: session.startedAt))–\(Self.timeFormatter.string(from: session.endedAt)) · \(session.durationMinutes) 分钟"
            )
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            if session.source == .stoppedEarly {
                Text("提前结束")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
    }
}
