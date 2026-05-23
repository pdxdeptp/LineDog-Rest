import AppKit
import SwiftUI

/// 单条首页任务行：拖拽把手、展开主体、完成按钮和学习链接动作相互独立。
struct TaskRowView: View {
    let task: AssistantTask
    let isExpanded: Bool
    let learningLink: TaskLearningLink
    let onToggleExpansion: () -> Void
    let onComplete: () async -> Void

    @State private var isCompleting = false
    @State private var progressFill: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                dragHandle

                Button(action: onToggleExpansion) {
                    rowBody
                }
                .buttonStyle(.plain)

                if task.priority == 1 {
                    Text("P1")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 4))
                }

                completeButton
            }

            if isExpanded {
                expandedDetails
                    .padding(.leading, 28)
            }

            if isCompleting {
                ProgressView(value: progressFill)
                    .progressViewStyle(.linear)
                    .tint(Color.accentColor)
                    .animation(.easeInOut(duration: 0.4), value: progressFill)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .frame(width: 18, height: 28)
            .help("拖动调整顺序")
            .accessibilityLabel("拖拽排序把手")
    }

    private var rowBody: some View {
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
    }

    private var completeButton: some View {
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
                .foregroundStyle(task.isCompleted ? Color.accentColor : Color.secondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(task.isCompleted || isCompleting)
        .help(task.isCompleted ? "已完成" : "标记完成")
    }

    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(task.resourceTitle ?? "未关联资料")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("目标 \(task.targetMinutes) 分钟")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            switch learningLink {
            case .available(let url):
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("打开链接", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderless)
            case .unavailable:
                Label("链接不可用", systemImage: "link.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
