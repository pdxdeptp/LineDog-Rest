import SwiftUI

struct NutritionTodayPanelView: View {
    let digitKeysEnabled: Bool

    @StateObject private var viewModel = NutritionTodayViewModel()
    @State private var digitMonitor: NutritionDigitKeyMonitor?

    /// 饮食区正文（不含「饮食」标题）：语义字号再加大一档。
    private enum NutritionBodyFont {
        static let dayLabel = Font.subheadline.weight(.semibold)
        static let kcalSummary = Font.callout.monospacedDigit().weight(.medium)
        static let macroLine = Font.footnote.monospacedDigit()
        static let section = Font.callout.weight(.semibold)
        static let body = Font.callout
        static let hint = Font.footnote
        static let suggestionIndex = Font.callout.monospacedDigit().weight(.semibold)
        static let suggestionMeta = Font.footnote.monospacedDigit()
        static let tableCell = Font.system(size: 12).monospacedDigit()
        static let tableHeader = Font.system(size: 12, weight: .semibold).monospacedDigit()
    }

    private enum NutritionChrome {
        /// 「饮食」标题上方：约半字行高。
        static let titleTopSpacing: CGFloat = 6
    }

    private enum EatenTableLayout {
        static let foodMinWidth: CGFloat = 68
        static let gramsWidth: CGFloat = 30
        static let kcalWidth: CGFloat = 38
        static let macroWidth: CGFloat = 30
        static let sodiumWidth: CGFloat = 34
    }

    init(digitKeysEnabled: Bool = true) {
        self.digitKeysEnabled = digitKeysEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            nutritionHeaderRow
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.loadToday()
            viewModel.startWatching()
            installDigitMonitor()
        }
        .onDisappear {
            digitMonitor?.stop()
            digitMonitor = nil
            viewModel.stopWatching()
        }
        .onChange(of: digitKeysEnabled) { _ in
            installDigitMonitor()
        }
    }

    private var loadedNutritionPanel: NutritionPanel? {
        if case .loaded(let log) = viewModel.loadState, let panel = log.panel {
            return panel
        }
        return nil
    }

    private var nutritionHeaderRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("饮食")
                .font(.title2.bold())
                .foregroundStyle(.red)

            if let panel = loadedNutritionPanel {
                Text(panel.dayLabel)
                    .font(NutritionBodyFont.dayLabel)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let workoutLabel = panel.workoutLabel, !workoutLabel.isEmpty {
                    Text(workoutLabel)
                        .font(NutritionBodyFont.dayLabel)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text("\(Int(panel.consumed.kcal.rounded())) / \(Int(panel.targets.kcal.rounded())) kcal")
                    .font(NutritionBodyFont.kcalSummary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.top, NutritionChrome.titleTopSpacing)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .leading)
        case .missingPanel:
            emptyPanelMessage
        case .failed(let message):
            Text(message)
                .font(NutritionBodyFont.body)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        case .loaded(let log):
            if let panel = log.panel {
                loadedPanel(log: log, panel: panel)
            } else {
                emptyPanelMessage
            }
        }
    }

    private var emptyPanelMessage: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("尚无饮食面板数据")
                .font(NutritionBodyFont.body)
                .foregroundStyle(.secondary)
            Text("在飞书告诉 Hermes 吃了什么，或等待晨报刷新 panel。")
                .font(NutritionBodyFont.hint)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func loadedPanel(log: NutritionDailyLog, panel: NutritionPanel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                calorieBar(consumed: panel.consumed.kcal, target: panel.targets.kcal)

                macroLine(panel: panel)

                if let notice = viewModel.actionNotice, !notice.isEmpty {
                    Text(notice)
                        .font(NutritionBodyFont.body)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("现在可以吃")
                    .font(NutritionBodyFont.section)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                recommendationSection
                    .id(panel.updatedAt + "-\(viewModel.loggableItems.count)")

                Text("已吃")
                    .font(NutritionBodyFont.section)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                if log.records.isEmpty {
                    Text("（暂无）")
                        .font(NutritionBodyFont.body)
                        .foregroundStyle(.tertiary)
                } else {
                    eatenRecordsTable(log.records)
                }
            }
            .padding(.vertical, 2)
        }
        .id(panel.updatedAt)
    }

    private func calorieBar(consumed: Double, target: Double) -> some View {
        let ratio = target > 0 ? min(max(consumed / target, 0), 1) : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.separatorColor).opacity(0.35))
                Capsule()
                    .fill(Color.accentColor.opacity(0.85))
                    .frame(width: geo.size.width * ratio)
            }
        }
        .frame(height: 6)
    }

    private func macroLine(panel: NutritionPanel) -> some View {
        let c = panel.consumed
        let r = panel.remaining
        let t = panel.targets
        return Text(
            "蛋白 \(formatG(c.proteinG))/\(formatG(t.proteinG)) · "
            + "碳水 \(formatG(c.carbsG))/\(formatG(t.carbsG)) · "
            + "脂肪 \(formatG(c.fatG))/\(formatG(t.fatG)) · "
            + "钠 \(formatMg(c.sodiumMg))/\(formatMg(t.sodiumMg)) mg"
        )
        .font(NutritionBodyFont.macroLine)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(
            "钠已摄入 \(formatMg(c.sodiumMg)) 毫克，剩余 \(formatMg(r.sodiumMg)) 毫克"
        )
    }

    @ViewBuilder
    private var recommendationSection: some View {
        switch viewModel.recommendationState {
        case .idle:
            Text("等待 Hermes 更新建议。")
                .font(NutritionBodyFont.body)
                .foregroundStyle(.tertiary)
        case .fresh(let snapshot):
            recommendationSnapshotView(snapshot, actionsEnabled: true)
        case .stale(let snapshot):
            VStack(alignment: .leading, spacing: 4) {
                recommendationMessageView
                recommendationSnapshotView(snapshot, actionsEnabled: false)
            }
        case .missing, .invalid:
            recommendationMessageView
        case .unavailable(let snapshot):
            VStack(alignment: .leading, spacing: 4) {
                recommendationMessageView
                if !snapshot.suggestions.isEmpty {
                    recommendationSnapshotView(snapshot, actionsEnabled: false)
                }
            }
        }
    }

    private var recommendationMessageView: some View {
        Text(viewModel.recommendationMessage ?? "等待 Hermes 更新建议。")
            .font(NutritionBodyFont.body)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func recommendationSnapshotView(
        _ snapshot: NutritionRecommendationSnapshot,
        actionsEnabled: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.summary)
                .font(NutritionBodyFont.body)
                .foregroundStyle(actionsEnabled ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(snapshot.suggestions) { suggestion in
                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.label)
                        .font(NutritionBodyFont.hint.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let rationale = suggestion.rationale, !rationale.isEmpty {
                        Text(rationale)
                            .font(NutritionBodyFont.hint)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(Array(suggestion.items.enumerated()), id: \.offset) { _, item in
                        recommendationItemRow(item, actionsEnabled: actionsEnabled)
                        Divider().opacity(0.35)
                    }
                    ForEach(suggestion.warnings, id: \.self) { warning in
                        Text(warning)
                            .font(NutritionBodyFont.hint)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if actionsEnabled, viewModel.loggableItems.count <= 9, !viewModel.loggableItems.isEmpty {
                Text("按 1–9 快捷记录")
                    .font(NutritionBodyFont.hint)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func recommendationItemRow(
        _ item: NutritionRecommendationItem,
        actionsEnabled: Bool
    ) -> some View {
        if actionsEnabled,
           item.loggable,
           let loggable = viewModel.loggableItems.first(where: { $0.sourceItemID == item.id }) {
            suggestionRow(loggable)
        } else {
            HStack(alignment: .center, spacing: 6) {
                Color.clear.frame(width: 18, height: 1)
                Text(item.displayName)
                    .font(NutritionBodyFont.body)
                    .foregroundStyle(actionsEnabled ? .primary : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if item.loggable, let grams = item.grams {
                    Text("\(formatG(grams))g")
                        .font(NutritionBodyFont.suggestionMeta)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func suggestionRow(_ item: NutritionLoggableItem) -> some View {
        let logging = viewModel.loggingFlatIndex == item.flatIndex
        return Button {
            Task { await viewModel.logItem(flatIndex: item.flatIndex) }
        } label: {
            HStack(alignment: .center, spacing: 6) {
                if item.flatIndex <= 9 {
                    Text("\(item.flatIndex).")
                        .font(NutritionBodyFont.suggestionIndex)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, alignment: .trailing)
                } else {
                    Color.clear.frame(width: 18, height: 1)
                }

                Text(item.displayName)
                    .font(NutritionBodyFont.body)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(formatG(item.grams))g")
                    .font(NutritionBodyFont.suggestionMeta)
                    .foregroundStyle(.secondary)

                if let kcal = item.kcal {
                    Text("\(Int(kcal.rounded())) kcal")
                        .font(NutritionBodyFont.suggestionMeta)
                        .foregroundStyle(.tertiary)
                }

                if logging {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLogging)
    }

    private func eatenRecordsTable(_ records: [NutritionDailyRecord]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 3) {
                GridRow {
                    eatenHeaderCell("食物", width: EatenTableLayout.foodMinWidth, alignment: .leading)
                    eatenHeaderCell("g", width: EatenTableLayout.gramsWidth)
                    eatenHeaderCell("kcal", width: EatenTableLayout.kcalWidth)
                    eatenHeaderCell("蛋白", width: EatenTableLayout.macroWidth)
                    eatenHeaderCell("碳水", width: EatenTableLayout.macroWidth)
                    eatenHeaderCell("脂肪", width: EatenTableLayout.macroWidth)
                    eatenHeaderCell("钠", width: EatenTableLayout.sodiumWidth)
                }
                .padding(.bottom, 2)

                Divider()
                    .gridCellColumns(7)
                    .padding(.vertical, 2)

                ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                    GridRow {
                        eatenDataCell(record.name, width: EatenTableLayout.foodMinWidth, alignment: .leading)
                            .lineLimit(2)
                        eatenDataCell(formatOptionalG(record.weightG), width: EatenTableLayout.gramsWidth)
                        eatenDataCell(formatOptionalInt(record.kcal), width: EatenTableLayout.kcalWidth)
                        eatenDataCell(formatOptionalG(record.proteinG), width: EatenTableLayout.macroWidth)
                        eatenDataCell(formatOptionalG(record.carbsG), width: EatenTableLayout.macroWidth)
                        eatenDataCell(formatOptionalG(record.fatG), width: EatenTableLayout.macroWidth)
                        eatenDataCell(formatOptionalMg(record.sodiumMg), width: EatenTableLayout.sodiumWidth)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func eatenHeaderCell(
        _ text: String,
        width: CGFloat,
        alignment: Alignment = .trailing
    ) -> some View {
        Text(text)
            .font(NutritionBodyFont.tableHeader)
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: alignment)
    }

    private func eatenDataCell(
        _ text: String,
        width: CGFloat,
        alignment: Alignment = .trailing
    ) -> some View {
        Text(text)
            .font(NutritionBodyFont.tableCell)
            .foregroundStyle(.primary)
            .frame(width: width, alignment: alignment)
    }

    private func formatOptionalG(_ value: Double?) -> String {
        guard let value else { return "—" }
        return formatG(value)
    }

    private func formatOptionalInt(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(Int(value.rounded()))
    }

    private func formatOptionalMg(_ value: Double?) -> String {
        guard let value else { return "—" }
        return formatMg(value)
    }

    private func formatG(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value.rounded())) }
        return String(format: "%.1f", value)
    }

    private func formatMg(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value.rounded())) }
        return String(format: "%.0f", value)
    }

    private func installDigitMonitor() {
        digitMonitor?.stop()
        let keysEnabled = digitKeysEnabled
        let monitor = NutritionDigitKeyMonitor(
            isEnabled: { [viewModel] in
                guard keysEnabled else { return false }
                return viewModel.canUseDigitShortcuts
            },
            onDigit: { digit in
                Task { await viewModel.logItem(flatIndex: digit) }
            }
        )
        monitor.start()
        digitMonitor = monitor
    }
}
