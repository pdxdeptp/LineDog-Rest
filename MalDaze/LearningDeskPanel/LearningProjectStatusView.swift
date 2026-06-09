import SwiftUI

enum LearningDeadlineEmphasis {
    case normal
    case approaching
    case overdue

    static func forDeadline(_ iso: String, today: Date = Date()) -> LearningDeadlineEmphasis {
        guard let date = LearningDeadlineEmphasis.parseISO(iso) else { return .normal }
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: today)
        let startDeadline = cal.startOfDay(for: date)
        if startDeadline < startToday { return .overdue }
        if let horizon = cal.date(byAdding: .day, value: 7, to: startToday),
           startDeadline <= horizon {
            return .approaching
        }
        return .normal
    }

    static func parseISO(_ iso: String) -> Date? {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return Calendar.current.date(from: components)
    }

    static func shortLabel(_ iso: String) -> String {
        guard let date = parseISO(iso) else { return iso }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

struct LearningProjectStatusView: View {
    let projects: [HermesStatusProject]
    let busyProjectIds: Set<String>
    var scrollToProjectId: String?
    let onJumpToToday: (String) -> Void
    let onBeginDeadlineEdit: (HermesStatusProject) -> Void
    let onBeginDeleteProject: (HermesStatusProject) -> Void

    var body: some View {
        if projects.isEmpty {
            Text("暂无学习项目。在 Hermes 对话发送学习链接，或说「帮我安排学习」。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(projects, id: \.projectId) { project in
                            projectCard(project)
                                .id(project.projectId)
                        }
                    }
                }
                .onChange(of: scrollToProjectId) { projectId in
                    guard let projectId else { return }
                    withAnimation {
                        proxy.scrollTo(projectId, anchor: .top)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func projectCard(_ project: HermesStatusProject) -> some View {
        let deemphasized = !project.isActive
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    onJumpToToday(project.projectId)
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(project.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(deemphasized ? .secondary : .primary)
                        Spacer(minLength: 4)
                        Text(project.status)
                            .font(.caption2)
                            .foregroundStyle(deemphasized ? .tertiary : .secondary)
                    }
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    onBeginDeleteProject(project)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(busyProjectIds.contains(project.projectId))
                .help("删除整个项目及全部任务")
            }

            progressLine(project, deemphasized: deemphasized)
            deadlineLine(project, deemphasized: deemphasized)
            nextTaskLine(project, deemphasized: deemphasized)

            if project.deadlineExceeded == true {
                Label("仍有课程排在新截止日之后，请延后截止日或删减任务", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(8)
        .background(
            Color(.controlBackgroundColor).opacity(deemphasized ? 0.25 : 0.55),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .opacity(deemphasized ? 0.75 : 1)
    }

    @ViewBuilder
    private func progressLine(_ project: HermesStatusProject, deemphasized: Bool) -> some View {
        if let progress = project.progress {
            let percent = project.percent.map { " · \($0)%" } ?? ""
            Text("\(progress)\(percent)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(deemphasized ? .tertiary : .secondary)
        }
    }

    @ViewBuilder
    private func deadlineLine(_ project: HermesStatusProject, deemphasized: Bool) -> some View {
        let emphasis = project.deadline.flatMap { LearningDeadlineEmphasis.forDeadline($0) } ?? .normal
        HStack(spacing: 8) {
            Text("截止")
                .font(.caption)
                .foregroundStyle(.secondary)

            if project.isActive {
                Button {
                    onBeginDeadlineEdit(project)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        if let deadline = project.deadline, !deadline.isEmpty {
                            Text(LearningDeadlineEmphasis.shortLabel(deadline))
                                .font(.caption.monospacedDigit().weight(.medium))
                        } else {
                            Text("设置日期")
                                .font(.caption.weight(.medium))
                        }
                        Text("修改")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(deadlineColor(emphasis, deemphasized: false))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(busyProjectIds.contains(project.projectId))
                .help("修改项目截止日")
            } else if let deadline = project.deadline, !deadline.isEmpty {
                Text(LearningDeadlineEmphasis.shortLabel(deadline))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(deadlineColor(emphasis, deemphasized: deemphasized))
            } else {
                Text("未设置")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if emphasis == .overdue {
                Text("已过期")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
    }

    private func deadlineColor(_ emphasis: LearningDeadlineEmphasis, deemphasized: Bool) -> Color {
        if deemphasized { return .secondary }
        switch emphasis {
        case .overdue: return .red
        case .approaching: return .orange
        case .normal: return .secondary
        }
    }

    @ViewBuilder
    private func nextTaskLine(_ project: HermesStatusProject, deemphasized: Bool) -> some View {
        if let next = project.nextTask {
            Button {
                onJumpToToday(project.projectId)
            } label: {
                HStack(spacing: 6) {
                    Text("待办")
                        .font(.caption.weight(.semibold))
                    Text(next.title)
                        .font(.caption)
                        .lineLimit(2)
                    if let date = next.scheduledDate {
                        Text(LearningDeadlineEmphasis.shortLabel(date))
                            .font(.caption2.monospacedDigit())
                    }
                    if let minutes = next.durationMinutes {
                        Text("\(minutes)m")
                            .font(.caption2.monospacedDigit())
                    }
                }
                .foregroundStyle(deemphasized ? .tertiary : .primary)
            }
            .buttonStyle(.plain)
        } else {
            Text("无待办任务")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

struct LearningDeadlineEditSheet: View {
    let session: LearningDeskPanelViewModel.DeadlineEditSession
    let preview: LearningDeskPanelViewModel.DeadlineRepackPreview?
    let onDateChange: (String) -> Void
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var pickedDate: Date

    init(
        session: LearningDeskPanelViewModel.DeadlineEditSession,
        preview: LearningDeskPanelViewModel.DeadlineRepackPreview?,
        onDateChange: @escaping (String) -> Void,
        onConfirm: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.session = session
        self.preview = preview
        self.onDateChange = onDateChange
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        let initial = LearningDeadlineEmphasis.parseISO(session.currentDeadline) ?? Date()
        _pickedDate = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("修改项目截止日")
                .font(.headline)
            Text(session.projectName)
                .font(.subheadline.weight(.semibold))

            DatePicker("新截止日", selection: $pickedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .onChange(of: pickedDate) { _ in
                    onDateChange(LearningDeskPanelViewModel.isoDate(pickedDate))
                }

            Text("未完成课程将从今天起重排到新截止日；已完成的课不变。")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let preview, canConfirm {
                if preview.changeCount > 0 {
                    Text("将移动 \(preview.changeCount) 节课")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if preview.overflowCount > 0 {
                    Text("\(preview.overflowCount) 节课无法排进新截止日，确认后仍保留在原日期")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            HStack {
                Button("取消", action: onCancel)
                Spacer()
                Button("确认") {
                    onConfirm(LearningDeskPanelViewModel.isoDate(pickedDate))
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canConfirm)
            }
        }
        .padding(20)
        .frame(minWidth: 340)
    }

    private var canConfirm: Bool {
        let newDeadline = LearningDeskPanelViewModel.isoDate(pickedDate)
        if newDeadline != session.currentDeadline { return true }
        guard let preview else { return false }
        return preview.changeCount > 0 || preview.overflowCount > 0
    }
}
