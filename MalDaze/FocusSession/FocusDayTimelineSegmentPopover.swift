import SwiftUI

struct FocusDayTimelineSegmentPopover: View {
    let segment: FocusDayTimelineFillSegment
    let onUpdate: (UUID, Date, Date) -> Void
    let onDelete: (UUID) -> Void
    let onDismiss: () -> Void

    @State private var isEditing = false
    @State private var editStartedAt: Date
    @State private var editEndedAt: Date

    init(
        segment: FocusDayTimelineFillSegment,
        onUpdate: @escaping (UUID, Date, Date) -> Void,
        onDelete: @escaping (UUID) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.segment = segment
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onDismiss = onDismiss
        _editStartedAt = State(initialValue: segment.sessionStartedAt)
        _editEndedAt = State(initialValue: segment.sessionEndedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(FocusDayTimelineFormatting.dateLine(segment.sessionStartedAt))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(FocusDayTimelineFormatting.timeRangeLine(
                    start: segment.sessionStartedAt,
                    end: segment.pomodoroPhaseEndsAt ?? segment.sessionEndedAt
                ))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                if segment.isInProgress,
                   let remaining = segment.pomodoroRemainingSeconds {
                    let configuredMinutes = FocusSessionFormatting.displayMinutes(
                        fromSeconds: FocusSessionFormatting.durationSeconds(
                            from: segment.sessionStartedAt,
                            to: segment.pomodoroPhaseEndsAt ?? segment.sessionEndedAt
                        )
                    )
                    Text("本颗番茄 · 已 \(segment.durationMinutes) / \(configuredMinutes) 分钟 · 剩余 \(Self.formatRemaining(remaining))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(segment.durationMinutes) 分钟 · \(FocusDayTimelineFormatting.sourceLabel(for: segment))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if segment.isInProgress {
                Text("完成后会记入番茄。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if segment.source == .completed, isEditing {
                editForm
            } else if segment.source == .completed, segment.sessionID != nil {
                Button("编辑") {
                    editStartedAt = segment.sessionStartedAt
                    editEndedAt = segment.sessionEndedAt
                    isEditing = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("删除", role: .destructive) {
                    if let sessionID = segment.sessionID {
                        onDelete(sessionID)
                    }
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(minWidth: 220, alignment: .leading)
    }

    private static func formatRemaining(_ seconds: Int) -> String {
        String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker("开始", selection: $editStartedAt, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
            DatePicker("结束", selection: $editEndedAt, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)

            HStack {
                Button("取消") {
                    isEditing = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer(minLength: 0)

                Button("保存") {
                    guard let sessionID = segment.sessionID, editEndedAt > editStartedAt else { return }
                    onUpdate(sessionID, editStartedAt, editEndedAt)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(editEndedAt <= editStartedAt)
            }
        }
    }
}
