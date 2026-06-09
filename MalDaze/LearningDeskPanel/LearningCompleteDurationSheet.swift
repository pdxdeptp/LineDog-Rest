import SwiftUI

struct LearningCompleteDurationSheet: View {
    let title: String
    let plannedMinutes: Int
    let onConfirm: (Int) -> Void
    let onCancel: () -> Void

    @State private var minutes: Int

    init(
        title: String,
        plannedMinutes: Int,
        onConfirm: @escaping (Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.plannedMinutes = plannedMinutes
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _minutes = State(initialValue: max(1, plannedMinutes))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("记录时长并完成")
                .font(.headline)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Stepper(value: $minutes, in: 1...480, step: 5) {
                Text("实际 \(minutes) 分钟（计划 \(plannedMinutes) 分钟）")
                    .font(.subheadline.monospacedDigit())
            }

            HStack {
                Button("取消", action: onCancel)
                Spacer()
                Button("完成") {
                    onConfirm(minutes)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 320)
    }
}
