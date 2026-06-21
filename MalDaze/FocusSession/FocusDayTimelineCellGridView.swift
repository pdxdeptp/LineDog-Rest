import SwiftUI

enum FocusDayTimelinePopoverTarget: Identifiable, Equatable {
    case success(FocusDayTimelineFillSegment)
    case failed(FocusDayTimelineFailedMarker)

    var id: String {
        switch self {
        case .success(let segment):
            return "success-\(segment.id)"
        case .failed(let marker):
            return "failed-\(marker.id)"
        }
    }
}

struct FocusDayTimelineCellGridView: View {
    let model: FocusDayTimelineCellGridModel
    let sessionCount: Int
    let totalMinutes: Int
    let hasActivity: Bool
    let onUpdateSession: (UUID, Date, Date) -> Void
    let onDeleteSession: (UUID) -> Void

    @State private var hoveredTargetID: String?
    @State private var pinnedTarget: FocusDayTimelinePopoverTarget?
    @State private var dismissPopoverTask: Task<Void, Never>?

    private let cellHeight: CGFloat = 16
    private let cellSpacing: CGFloat = 3
    private let labelWidth: CGFloat = 28
    private static let cellBorderColor = Color(nsColor: .separatorColor).opacity(0.55)

    private var activeTarget: FocusDayTimelinePopoverTarget? {
        if let pinnedTarget {
            return pinnedTarget
        }
        guard let hoveredTargetID else { return nil }
        return allPopoverTargets.first { $0.id == hoveredTargetID }
    }

    private var allPopoverTargets: [FocusDayTimelinePopoverTarget] {
        model.cells.flatMap { cell in
            cell.fillSegments.map(FocusDayTimelinePopoverTarget.success)
                + cell.failedMarkers.map(FocusDayTimelinePopoverTarget.failed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("专注")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: labelWidth, alignment: .leading)

                if hasActivity {
                    Spacer(minLength: 0)
                    Text("\(sessionCount) 个 · \(totalMinutes) 分钟")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("今天还没有专注")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 0)
                }
            }

            cellRow(cells: hasActivity ? model.cells : [])
                .frame(height: cellHeight)
                .padding(.leading, labelWidth + 8)
                .popover(item: activeTargetBinding, arrowEdge: .top) { target in
                    popoverContent(for: target)
                        .onHover { hovering in
                            if hovering {
                                cancelDismissPopoverTask()
                            } else {
                                scheduleDismissPopoverUnlessPinned()
                            }
                        }
                }

            if hasActivity {
                tickRow
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private func popoverContent(for target: FocusDayTimelinePopoverTarget) -> some View {
        switch target {
        case .success(let segment):
            FocusDayTimelineSegmentPopover(
                segment: segment,
                onUpdate: onUpdateSession,
                onDelete: onDeleteSession,
                onDismiss: dismissPopover
            )
        case .failed(let marker):
            FocusDayTimelineFailedMarkerPopover(
                marker: marker,
                onDelete: onDeleteSession,
                onDismiss: dismissPopover
            )
        }
    }

    private var activeTargetBinding: Binding<FocusDayTimelinePopoverTarget?> {
        Binding(
            get: { activeTarget },
            set: { newValue in
                if newValue == nil {
                    pinnedTarget = nil
                    hoveredTargetID = nil
                }
            }
        )
    }

    private var accessibilitySummary: String {
        if !hasActivity {
            return "专注，今天还没有专注"
        }
        return "专注，\(sessionCount) 个，共 \(totalMinutes) 分钟"
    }

    private func cellRow(cells: [FocusDayTimelineCell]) -> some View {
        GeometryReader { geo in
            let count = cells.isEmpty
                ? FocusDayTimelineCellGridModel.defaultVisibleCellCount
                : cells.count
            let totalSpacing = cellSpacing * CGFloat(max(0, count - 1))
            let cellWidth = max(8, (geo.size.width - totalSpacing) / CGFloat(count))

            HStack(spacing: cellSpacing) {
                if cells.isEmpty {
                    ForEach(0..<count, id: \.self) { _ in
                        FocusDayTimelineEmptyCellView(borderColor: Self.cellBorderColor)
                            .frame(width: cellWidth, height: cellHeight)
                    }
                } else {
                    ForEach(cells, id: \.index) { cell in
                        FocusDayTimelineCellView(
                            cell: cell,
                            cellWidth: cellWidth,
                            cellHeight: cellHeight,
                            borderColor: Self.cellBorderColor,
                            hoveredTargetID: hoveredTargetID,
                            onHoverTarget: handleTargetHover,
                            onPinTarget: pinTarget
                        )
                    }
                }
            }
        }
    }

    private var tickRow: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(model.tickHours, id: \.self) { hour in
                    if let x = tickX(for: hour, width: geo.size.width) {
                        Text(tickLabel(for: hour))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                            .position(x: x, y: 6)
                    }
                }
            }
        }
        .frame(height: 12)
        .padding(.leading, labelWidth + 8)
    }

    private func handleTargetHover(_ target: FocusDayTimelinePopoverTarget, isHovering: Bool) {
        cancelDismissPopoverTask()
        if isHovering {
            hoveredTargetID = target.id
        } else {
            scheduleDismissPopoverUnlessPinned()
        }
    }

    private func pinTarget(_ target: FocusDayTimelinePopoverTarget) {
        cancelDismissPopoverTask()
        pinnedTarget = target
        hoveredTargetID = target.id
    }

    private func dismissPopover() {
        pinnedTarget = nil
        hoveredTargetID = nil
    }

    private func scheduleDismissPopoverUnlessPinned() {
        cancelDismissPopoverTask()
        dismissPopoverTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            if pinnedTarget == nil {
                hoveredTargetID = nil
            }
        }
    }

    private func cancelDismissPopoverTask() {
        dismissPopoverTask?.cancel()
        dismissPopoverTask = nil
    }

    private func tickX(for hour: Int, width: CGFloat) -> CGFloat? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: model.visibleStart)
        guard let marker = calendar.date(byAdding: .hour, value: hour, to: dayStart) else { return nil }
        let span = model.visibleEnd.timeIntervalSince(model.visibleStart)
        guard span > 0, marker >= model.visibleStart, marker <= model.visibleEnd else { return nil }
        let fraction = marker.timeIntervalSince(model.visibleStart) / span
        return max(0, min(width, CGFloat(fraction) * width))
    }

    private func tickLabel(for hour: Int) -> String {
        hour == FocusDayTimelineCellGridModel.baseEndHour ? "24" : "\(hour)"
    }
}

private struct FocusDayTimelineEmptyCellView: View {
    let borderColor: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color(.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
    }
}

private struct FocusDayTimelineCellView: View {
    let cell: FocusDayTimelineCell
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let borderColor: Color
    let hoveredTargetID: String?
    let onHoverTarget: (FocusDayTimelinePopoverTarget, Bool) -> Void
    let onPinTarget: (FocusDayTimelinePopoverTarget) -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 0.5)
                )

            ForEach(cell.fillSegments) { segment in
                FocusDayTimelineFillSegmentView(
                    segment: segment,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight,
                    isHovered: hoveredTargetID == FocusDayTimelinePopoverTarget.success(segment).id,
                    onHover: { onHoverTarget(.success(segment), $0) },
                    onPin: { onPinTarget(.success(segment)) }
                )
            }

            ForEach(cell.failedMarkers) { marker in
                FocusDayTimelineFailedMarkerView(
                    marker: marker,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight,
                    isHovered: hoveredTargetID == FocusDayTimelinePopoverTarget.failed(marker).id,
                    onHover: { onHoverTarget(.failed(marker), $0) },
                    onPin: { onPinTarget(.failed(marker)) }
                )
            }
        }
        .frame(width: cellWidth, height: cellHeight)
    }
}

private struct FocusDayTimelineFillSegmentView: View {
    let segment: FocusDayTimelineFillSegment
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onPin: () -> Void

    private var fillWidth: CGFloat {
        max(
            FocusDayTimelineCellGridModel.minFillWidthPoints,
            cellWidth * CGFloat(segment.widthFraction)
        )
    }

    private var fillOffset: CGFloat {
        cellWidth * CGFloat(segment.startFraction)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color.accentColor.opacity(isHovered ? 1.0 : 0.9))
            .frame(width: fillWidth, height: cellHeight)
            .offset(x: fillOffset)
            .contentShape(Rectangle())
            .help(FocusDayTimelineFormatting.hoverHelp(for: segment))
            .onHover(perform: onHover)
            .onTapGesture(perform: onPin)
            .accessibilityLabel(FocusDayTimelineFormatting.hoverHelp(for: segment))
    }
}

private struct FocusDayTimelineFailedMarkerView: View {
    let marker: FocusDayTimelineFailedMarker
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onPin: () -> Void

    private var markerOffset: CGFloat {
        max(0, min(cellWidth - FocusDayTimelineCellGridModel.failedMarkerWidthPoints, cellWidth * CGFloat(marker.startFraction)))
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Color.brown.opacity(isHovered ? 0.85 : 0.55))
            .frame(width: FocusDayTimelineCellGridModel.failedMarkerWidthPoints, height: cellHeight - 4)
            .offset(x: markerOffset, y: 2)
            .contentShape(Rectangle())
            .help(FocusDayTimelineFormatting.failedMarkerLabel(for: marker))
            .onHover(perform: onHover)
            .onTapGesture(perform: onPin)
            .accessibilityLabel(FocusDayTimelineFormatting.failedMarkerLabel(for: marker))
    }
}
