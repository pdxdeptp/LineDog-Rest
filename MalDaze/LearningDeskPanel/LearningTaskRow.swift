import SwiftUI

struct LearningTaskRow: View {
    let row: LearningTaskDisplayRow
    let isBusy: Bool
    let onComplete: () -> Void
    let onPostponeTomorrow: () -> Void
    let onPickDate: (Date) -> Void

    @State private var pickedDate = Date()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onComplete) {
                Image(systemName: "circle")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel("完成任务")

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

            Menu {
                Button("推迟到明天", action: onPostponeTomorrow)
                DatePicker(
                    "选择日期",
                    selection: $pickedDate,
                    displayedComponents: .date
                )
                .onChange(of: pickedDate) { newValue in
                    onPickDate(newValue)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
            }
            .menuStyle(.borderlessButton)
            .disabled(isBusy)
        }
        .opacity(isBusy ? 0.55 : 1)
    }
}
