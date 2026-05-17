import AppKit
import SwiftUI

/// 单个资料的进度卡片：进度条 + 完成单元数 / 总数 + 投入小时 + deadline。
struct ResourceProgressView: View {
    let resource: AssistantResource
    let isManagementInFlight: Bool
    let onOpen: (URL) -> Void
    let onAdjustPlan: () -> Void
    let onComplete: () async -> Void
    let onArchive: () async -> Void

    @State private var isLocalManagementInFlight = false

    init(
        resource: AssistantResource,
        isManagementInFlight: Bool = false,
        onOpen: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) },
        onAdjustPlan: @escaping () -> Void = {},
        onComplete: @escaping () async -> Void = {},
        onArchive: @escaping () async -> Void = {}
    ) {
        self.resource = resource
        self.isManagementInFlight = isManagementInFlight
        self.onOpen = onOpen
        self.onAdjustPlan = onAdjustPlan
        self.onComplete = onComplete
        self.onArchive = onArchive
    }

    private var progress: Double {
        guard resource.totalUnits > 0 else { return 0 }
        return Double(resource.completedUnits) / Double(resource.totalUnits)
    }

    private var progressLabel: String {
        "\(resource.completedUnits) / \(resource.totalUnits) 单元"
    }

    private var hoursLabel: String {
        let h = resource.actualMinutesTotal / 60
        let m = resource.actualMinutesTotal % 60
        if h > 0 {
            return "已投入 \(h) 小时 \(m) 分"
        }
        return "已投入 \(m) 分钟"
    }

    private var isResourceManagementInFlight: Bool {
        isManagementInFlight || isLocalManagementInFlight
    }

    private var deadlineLabel: String? {
        guard let dl = resource.deadline, !dl.isEmpty else { return nil }
        // 简单截取 ISO 日期前 10 字符显示
        let prefix = String(dl.prefix(10))
        return "截止 \(prefix)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(resource.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                statusBadge
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(progressTint)

            HStack(spacing: 8) {
                Text(progressLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(hoursLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let dl = deadlineLabel {
                    Text(dl)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            resourceActions
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private var resourceActions: some View {
        HStack(spacing: 8) {
            Button {
                if let url = resource.resourceURL {
                    onOpen(url)
                }
            } label: {
                Image(systemName: "safari")
            }
            .disabled(resource.resourceURL == nil)
            .help(resource.resourceURL == nil ? "资料链接不可用" : "打开资料")

            Button {
                onAdjustPlan()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .help("调整计划")

            Spacer(minLength: 8)

            Button {
                runManagementAction(onComplete)
            } label: {
                Image(systemName: "checkmark.circle")
            }
            .disabled(isResourceManagementInFlight)
            .help("标记完成")

            Button {
                runManagementAction(onArchive)
            } label: {
                Image(systemName: "minus.circle")
            }
            .disabled(isResourceManagementInFlight)
            .help("移出当前计划")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func runManagementAction(_ action: @escaping () async -> Void) {
        guard !isResourceManagementInFlight else { return }
        isLocalManagementInFlight = true
        Task {
            await action()
            isLocalManagementInFlight = false
        }
    }

    private var progressTint: Color {
        switch resource.status {
        case "completed": return .green
        case "overdue":   return .red
        default:          return .blue
        }
    }

    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            switch resource.status {
            case "completed": return ("已完成", .green)
            case "overdue":   return ("已超期", .red)
            case "active":    return ("进行中", .blue)
            default:          return (resource.status, .secondary)
            }
        }()
        return Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }
}
