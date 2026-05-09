import SwiftUI

/// 单条任务行：显示标题、资料来源、目标分钟；点击 ✓ 完成并触发进度动画。
struct TaskRowView: View {
    let task: AssistantTask
    let onComplete: () async -> Void

    @State private var isCompleting = false
    @State private var progressFill: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                // 完成按钮
                Button {
                    guard !task.isCompleted, !isCompleting else { return }
                    isCompleting = true
                    withAnimation(.easeInOut(duration: 0.4)) {
                        progressFill = 1.0
                    }
                    Task {
                        await onComplete()
                        isCompleting = false
                    }
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(task.isCompleted || isCompleting)
                .help(task.isCompleted ? "已完成" : "标记完成")

                // 标题
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.body)
                        .lineLimit(2)
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)

                    HStack(spacing: 6) {
                        if let resource = task.resourceTitle {
                            Text(resource)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Text("目标 \(task.targetMinutes) 分钟")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 优先级标记
                if task.priority == 1 {
                    Text("P1")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 4))
                }
            }

            // 完成进度动画条
            if isCompleting {
                ProgressView(value: progressFill)
                    .progressViewStyle(.linear)
                    .tint(.green)
                    .animation(.easeInOut(duration: 0.4), value: progressFill)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
    }
}
