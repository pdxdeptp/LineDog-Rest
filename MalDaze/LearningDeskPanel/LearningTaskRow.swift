import SwiftUI

struct LearningTaskRow: View {
    let row: LearningTaskDisplayRow
    let isBusy: Bool
    var isHighlighted: Bool = false
    var showReviewActions: Bool = false
    let onComplete: () -> Void
    var onCompleteWithDuration: (() -> Void)?
    let onPostponeTomorrow: () -> Void
    let onPickDate: (Date) -> Void
    var onDelete: (() -> Void)?
    var onReviewPassed: (() -> Void)?
    var onReviewFailed: (() -> Void)?
    var onOpenSourceURL: (() -> Void)?

    @State private var pickedDate = Date()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if showReviewActions {
                reviewButtons
            } else {
                Button(action: onComplete) {
                    Image(systemName: "circle")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityLabel("完成任务")
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(row.pending.index).")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(row.pending.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(3)
                }

                HStack(spacing: 8) {
                    Text(row.pending.projectName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(row.pending.durationMinutes) 分钟")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if row.autoRollDays >= 1 {
                        Text("已滚 \(row.autoRollDays) 天")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                    }
                }
            }

            Spacer(minLength: 0)

            if let onOpenSourceURL, row.pending.sourceUrl != nil {
                Button(action: onOpenSourceURL) {
                    Image(systemName: "link")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("打开学习链接")
            }

            Menu {
                if let onCompleteWithDuration, !showReviewActions {
                    Button("记录时长并完成", action: onCompleteWithDuration)
                    Divider()
                }
                Button("推迟到明天", action: onPostponeTomorrow)
                DatePicker(
                    "选择日期",
                    selection: $pickedDate,
                    displayedComponents: .date
                )
                .onChange(of: pickedDate) { newValue in
                    onPickDate(newValue)
                }
                if let onDelete {
                    Divider()
                    Button("删除", role: .destructive, action: onDelete)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
            }
            .menuStyle(.borderlessButton)
            .disabled(isBusy)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            isHighlighted ? Color.accentColor.opacity(0.18) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .opacity(isBusy ? 0.55 : 1)
    }

    @ViewBuilder
    private var reviewButtons: some View {
        HStack(spacing: 4) {
            Button(action: { onReviewPassed?() }) {
                Image(systemName: "checkmark.circle")
                    .font(.body)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel("复习通过")

            Button(action: { onReviewFailed?() }) {
                Image(systemName: "xmark.circle")
                    .font(.body)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel("复习未通过")
        }
    }
}
