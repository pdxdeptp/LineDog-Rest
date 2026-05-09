import SwiftUI

/// 学习助手中间栏：Tab 切换 今日任务 / 资料进度 / 对话 / 添加资料。
/// 后端离线时显示"助手离线"占位视图，不影响左右栏。
struct AssistantPanelView: View {
    @StateObject private var vm = LearningAssistantViewModel()
    @State private var selectedTab: AssistantTab = .tasks

    enum AssistantTab: String, CaseIterable {
        case tasks     = "今日任务"
        case resources = "资料进度"
        case chat      = "对话"
        case ingest    = "添加资料"

        var icon: String {
            switch self {
            case .tasks:     return "checkmark.circle"
            case .resources: return "chart.bar"
            case .chat:      return "bubble.left.and.bubble.right"
            case .ingest:    return "plus.circle"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题行
            panelHeader

            Divider()

            if vm.isConnecting {
                connectingPlaceholder
            } else if vm.isOffline {
                offlinePlaceholder
            } else {
                tabContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("学习助手")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Button {
                Task { await vm.fetchTodayBriefing() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("刷新今日简报")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Connecting

    private var connectingPlaceholder: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Text("后端启动中…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Offline

    private var offlinePlaceholder: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("助手离线")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("后端（localhost:8765）无法连接。\n请确认助手服务已启动。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button("重试") {
                Task { await vm.fetchTodayBriefing() }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Tab Content

    private var tabContent: some View {
        VStack(spacing: 0) {
            // Tab 选择器
            Picker("", selection: $selectedTab) {
                ForEach(AssistantTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            // 内容区
            switch selectedTab {
            case .tasks:
                tasksTab
            case .resources:
                resourcesTab
            case .chat:
                ChatView(vm: vm)
            case .ingest:
                IngestionView(vm: vm)
            }
        }
    }

    // MARK: - Tasks Tab

    private var tasksTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 摘要行
                if !vm.todayHighlights.isEmpty || vm.todayTotalMinutes > 0 {
                    summaryRow
                    Divider().padding(.horizontal, 4)
                }

                if vm.tasks.isEmpty {
                    emptyTasksHint
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(vm.tasks) { task in
                            TaskRowView(task: task) {
                                await vm.completeTask(task)
                            }
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .refreshable { await vm.fetchTodayBriefing() }
    }

    private var summaryRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("今日目标", systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(vm.todayTotalMinutes) 分钟")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if !vm.todayHighlights.isEmpty {
                Text(vm.todayHighlights)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    private var emptyTasksHint: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 16)
            Text("今日暂无学习任务")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Text("可在「添加资料」页面分析新资料，\n或等待明日早晨助手自动安排。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Resources Tab

    private var resourcesTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if vm.resources.isEmpty {
                    VStack(spacing: 8) {
                        Spacer(minLength: 16)
                        Text("暂无资料记录")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(vm.resources) { resource in
                        ResourceProgressView(resource: resource)
                        Divider().padding(.horizontal, 4)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await vm.fetchResources() }
    }
}
