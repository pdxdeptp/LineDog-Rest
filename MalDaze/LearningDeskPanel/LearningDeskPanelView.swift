import SwiftUI

struct LearningDeskPanelView: View {
    @StateObject private var viewModel = LearningDeskPanelViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .background(Color(.controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .task {
            await viewModel.loadToday()
        }
        .sheet(item: $viewModel.movePreview) { preview in
            LearningMovePreviewSheet(
                preview: preview,
                onConfirm: { Task { await viewModel.confirmMove() } },
                onCancel: { viewModel.cancelMovePreview() }
            )
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .center) {
            Label("学习", systemImage: "book.closed")
                .font(.headline)
            Spacer()
            Button {
                Task { await viewModel.loadToday() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("刷新")
        }

        if let notice = viewModel.actionNotice {
            Text(notice)
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            ProgressView("加载今日学习任务…")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text("无法加载学习面板")
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("确认 ~/.hermes/scripts/schedule.py 存在。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(8)
        case .loaded(let snapshot):
            loadedBody(snapshot: snapshot)
        }
    }

    @ViewBuilder
    private func loadedBody(snapshot: LearningTodaySnapshot) -> some View {
        let response = snapshot.response
        budgetHeader(response: response)

        if !response.warnings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(response.warnings) { warning in
                    Label(
                        "\(warning.projectName) 落后 \(warning.daysBehind) 天",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
        }

        if response.isRestDay {
            Text("今日休息")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        if snapshot.rows.isEmpty {
            Text(response.isRestDay ? "休息日无学习任务。" : "今日无学习任务。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !snapshot.studyRows.isEmpty {
                        sectionTitle("正课")
                        ForEach(snapshot.studyRows) { row in
                            taskRow(row)
                        }
                    }
                    if !snapshot.reviewRows.isEmpty {
                        sectionTitle("复习")
                        ForEach(snapshot.reviewRows) { row in
                            taskRow(row)
                        }
                    }
                }
            }
        }
    }

    private func budgetHeader(response: HermesTodayResponse) -> some View {
        let total = response.study.totalMinutes
        let budget = response.study.budget
        let over = total > budget
        return HStack(spacing: 8) {
            Text(response.date)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(total) / \(budget) 分钟")
                .font(.caption.weight(.semibold))
                .foregroundStyle(over ? .red : .primary)
            if over {
                Text("超额")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.red)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func taskRow(_ row: LearningTaskDisplayRow) -> some View {
        let busy = viewModel.busyTaskIds.contains(row.pending.taskId)
        return LearningTaskRow(
            row: row,
            isBusy: busy,
            onComplete: {
                Task { await viewModel.complete(taskId: row.pending.taskId) }
            },
            onPostponeTomorrow: {
                Task {
                    await viewModel.requestMove(
                        taskId: row.pending.taskId,
                        taskTitle: row.pending.title,
                        newDate: LearningDeskPanelViewModel.tomorrowISO()
                    )
                }
            },
            onPickDate: { date in
                Task {
                    await viewModel.requestMove(
                        taskId: row.pending.taskId,
                        taskTitle: row.pending.title,
                        newDate: LearningDeskPanelViewModel.isoDate(date)
                    )
                }
            }
        )
    }
}
