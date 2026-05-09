import SwiftUI

/// 添加学习资料：URL + deadline + speed_factor → 草稿展示 → 确认写入。
struct IngestionView: View {
    @ObservedObject var vm: LearningAssistantViewModel

    @State private var urlText: String = ""
    @State private var deadline: Date  = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var speedFactor: Double = 1.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // URL 输入
                VStack(alignment: .leading, spacing: 4) {
                    Label("资料链接", systemImage: "link")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("GitHub / Bilibili / PDF URL…", text: $urlText)
                        .textFieldStyle(.roundedBorder)
                }

                // Deadline
                VStack(alignment: .leading, spacing: 4) {
                    Label("学习截止日", systemImage: "calendar")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $deadline, in: Date()..., displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                // Speed Factor
                VStack(alignment: .leading, spacing: 4) {
                    Label("学习速度系数：\(String(format: "%.1f", speedFactor))×",
                          systemImage: "speedometer")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Slider(value: $speedFactor, in: 0.5...2.0, step: 0.1)
                    HStack {
                        Text("0.5× 慢")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("2.0× 快")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // 分析按钮
                Button {
                    Task { await vm.startIngestion(url: urlText, deadline: deadline, speedFactor: speedFactor) }
                } label: {
                    if vm.isIngesting {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("分析中…")
                        }
                    } else {
                        Label("分析", systemImage: "magnifyingglass")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isIngesting)
                .frame(maxWidth: .infinity, alignment: .leading)

                // 草稿区
                if let draft = vm.ingestionDraft {
                    draftSection(draft)
                        .transition(.opacity)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }

    // MARK: - Draft Section

    private func draftSection(_ draft: IngestionDraftDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("生成草稿", systemImage: "doc.text")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)

            // Summary info
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.resourceTitle)
                    .font(.callout.weight(.semibold))
                HStack(spacing: 12) {
                    Label("\(draft.unitCount) 集/章", systemImage: "list.number")
                    Label(String(format: "%.1f 小时", draft.totalEstimatedHours), systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(.separatorColor).opacity(0.4), lineWidth: 0.5)
            )

            // Option picker
            HStack(spacing: 0) {
                ForEach(["A", "B"], id: \.self) { opt in
                    let label = opt == "A" ? "方案 A（填空档）" : "方案 B（均匀铺开）"
                    Button(label) { vm.selectedOption = opt }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.plain)
                        .padding(.vertical, 6)
                        .background(vm.selectedOption == opt ? Color.accentColor.opacity(0.15) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .strokeBorder(Color.accentColor.opacity(vm.selectedOption == opt ? 0.4 : 0.1),
                                              lineWidth: 0.5)
                        )
                        .font(.caption.weight(vm.selectedOption == opt ? .semibold : .regular))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(.separatorColor).opacity(0.4), lineWidth: 0.5))

            HStack(spacing: 8) {
                Button("确认写入") {
                    Task { await vm.confirmIngestion(confirmed: true) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button("取消") {
                    Task { await vm.confirmIngestion(confirmed: false) }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.blue.opacity(0.2), lineWidth: 0.5)
        )
    }
}
