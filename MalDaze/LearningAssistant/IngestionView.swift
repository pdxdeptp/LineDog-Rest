import SwiftUI

struct IngestionView: View {
    @ObservedObject var vm: LearningAssistantViewModel

    @State private var urlText: String = ""
    @State private var deadline: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var speedFactor: Double = 1.0
    @State private var showFullPlan: Bool = false
    @State private var dailyCapacityMin: Int = 60

    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                urlInputSection

                if vm.isIngesting {
                    progressSection
                } else if let draft = vm.ingestionDraft {
                    draftSection(draft)
                        .transition(.opacity)
                } else if let error = vm.ingestionError {
                    if error == "session_expired" {
                        sessionExpiredBanner
                    } else {
                        errorBanner(error)
                    }
                } else {
                    analyzeButton
                }

                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .onDisappear { vm.cancelAnalysis() }
    }

    // MARK: - URL Input

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("资料链接", systemImage: "link")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("GitHub / Bilibili / PDF URL…", text: $urlText)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Analyze Button

    private var analyzeButton: some View {
        Button {
            Task {
                await vm.startIngestion(url: urlText, deadline: deadline, speedFactor: speedFactor)
            }
        } label: {
            Label("分析", systemImage: "magnifyingglass")
        }
        .buttonStyle(.borderedProminent)
        .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let phases: [(String, String)] = [
                ("fetch_structure", "读取章节结构"),
                ("estimate_time", "估算学习时长"),
                ("check_capacity", "生成排期方案"),
                ("draft_ready", "草稿已就绪"),
            ]
            ForEach(phases, id: \.0) { phase, label in
                let isCurrent = vm.ingestionPhase?.contains(label) == true || vm.ingestionPhase?.contains(phase) == true
                HStack(spacing: 6) {
                    if isCurrent {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "circle")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(isCurrent ? .primary : .tertiary)
                }
            }

            if let phaseLabel = vm.ingestionPhase {
                Text(phaseLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Draft Section

    private func draftSection(_ draft: IngestionDraftDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Resource info
            resourceInfoCard(draft)

            // Option picker
            HStack(spacing: 0) {
                optionButton(opt: "A", label: "尽快学完")
                optionButton(opt: "B", label: "均匀铺开")
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(.separatorColor).opacity(0.4), lineWidth: 0.5))

            // View full plan button
            Button("查看完整计划 →") {
                showFullPlan = true
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .sheet(isPresented: $showFullPlan) {
                let schedule = vm.selectedOption == "A" ? draft.optionA : draft.optionB
                FullPlanSheetView(
                    schedule: schedule,
                    totalUnitCount: draft.unitCount,
                    selectedOption: vm.selectedOption,
                    deadline: formatter.string(from: deadline)
                )
            }

            Divider()

            // Deadline DatePicker
            VStack(alignment: .leading, spacing: 4) {
                Label("截止日期", systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                DatePicker("", selection: $deadline, in: Date()..., displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .onChange(of: deadline) { newDate in
                        let newDeadlineStr = formatter.string(from: newDate)
                        vm.currentDeadline = newDeadlineStr
                        vm.debounceReschedule(deadline: newDeadlineStr, speedFactor: speedFactor)
                    }
            }

            // Speed Slider
            VStack(alignment: .leading, spacing: 4) {
                Label("速度：\(String(format: "%.1f", speedFactor))×", systemImage: "speedometer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Slider(value: $speedFactor, in: 0.5...2.0, step: 0.1)
                    .onChange(of: speedFactor) { newVal in
                        vm.currentSpeedFactor = newVal
                        vm.debounceReschedule(deadline: formatter.string(from: deadline), speedFactor: newVal)
                    }
            }

            // Daily capacity row
            HStack {
                Label("每日容量：\(dailyCapacityMin) 分钟", systemImage: "gauge")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("去设置 →") {
                    vm.selectedPanelTab = .settings
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
            }

            // Reschedule error
            if vm.rescheduleError {
                Text("重新排期失败，请稍后重试")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            // Confirm / Cancel buttons
            HStack(spacing: 8) {
                Button("确认写入") {
                    Task { await vm.confirmIngestion(confirmed: true) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.canConfirm)
                .opacity(vm.canConfirm ? 1.0 : 0.4)

                Button("取消") {
                    vm.confirmIngestion(cancelDraft: true)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.blue.opacity(0.2), lineWidth: 0.5))
        .onAppear {
            Task {
                guard let url = URL(string: "http://localhost:8765/api/settings/learning-preferences"),
                      let (data, _) = try? await URLSession.shared.data(from: url),
                      let json = try? JSONDecoder().decode([String: Int].self, from: data),
                      let cap = json["daily_capacity_min"] else { return }
                dailyCapacityMin = cap
            }
        }
    }

    // MARK: - Error states

    private var sessionExpiredBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("分析会话已失效，请重新提交链接", systemImage: "exclamationmark.triangle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            analyzeButton
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func errorBanner(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(msg, systemImage: "xmark.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
            analyzeButton
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private func resourceInfoCard(_ draft: IngestionDraftDetail) -> some View {
        let hoursLabel = String(format: "%.1f 小时", draft.totalEstimatedHours)
        let unitLabel = "\(draft.unitCount) 集/章"
        let typeLabel = resourceTypeLabel(draft.resourceType)
        return VStack(alignment: .leading, spacing: 4) {
            Text(draft.resourceTitle)
                .font(.callout.weight(.semibold))
            HStack(spacing: 12) {
                Label(typeLabel, systemImage: "doc")
                Label(unitLabel, systemImage: "list.number")
                Label(hoursLabel, systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func optionButton(opt: String, label: String) -> some View {
        let isSelected = vm.selectedOption == opt
        return Button {
            vm.selectedOption = opt
        } label: {
            Text(label)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .font(.caption.weight(isSelected ? .semibold : .regular))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(Color.accentColor.opacity(isSelected ? 0.4 : 0.1), lineWidth: 0.5)
        )
    }

    private func resourceTypeLabel(_ type: String) -> String {
        switch type {
        case "bilibili_series": return "B站合集"
        case "github", "github_repo": return "GitHub 仓库"
        case "pdf": return "PDF 文档"
        default: return "网页"
        }
    }
}
