import AppKit

enum DashboardLayout {
    /// 左栏基准 300pt；+15% 以容纳饮食宏量表（≈345pt）。
    static let remindersColumnWidth: CGFloat = 300 * 1.15
    static let learningColumnMinWidth: CGFloat = 360
    static let controlsColumnWidth: CGFloat = 300
    static let horizontalPadding: CGFloat = 12
    static let dividerWidth: CGFloat = 1
    static let safeHorizontalMargin: CGFloat = 48
    static let baseContentHeight: CGFloat = 664
    /// 整板相对基准尺寸的缩放（宽 +5%、高 +15%）。
    static let panelWidthScale: CGFloat = 1.05
    static let panelHeightScale: CGFloat = 1.15
    static var contentHeight: CGFloat { baseContentHeight * panelHeightScale }
    static let fallbackVisibleFrame = NSRect(x: 0, y: 0, width: 1280, height: 800)
    static let columnWidthMin: CGFloat = 240
    static let middleColumnWidthMin: CGFloat = 280
    static let columnResizeHandleWidth: CGFloat = 8
    static let defaultLeftPlanFraction = 0.6
    static let leftPlanFractionMin = 0.4
    static let leftPlanFractionMax = 0.75

    static let learningTodayHermesTaskFractionMin = 0.28
    static let learningTodayHermesTaskFractionMax = 0.82
    static let defaultLearningTodayHermesTaskFraction = 0.62

    static func clampedLearningTodayHermesTaskFraction(_ value: Double) -> Double {
        let base = value == 0 ? defaultLearningTodayHermesTaskFraction : value
        return min(max(base, learningTodayHermesTaskFractionMin), learningTodayHermesTaskFractionMax)
    }

    static var baseMinimumContentWidth: CGFloat {
        remindersColumnWidth
        + learningColumnMinWidth
        + controlsColumnWidth
        + 6 * horizontalPadding
        + columnResizeHandleWidth * 2
    }

    static var minimumContentWidth: CGFloat {
        baseMinimumContentWidth * panelWidthScale
    }

    static func preferredContentSize(screenVisibleFrame visibleFrame: NSRect?) -> NSSize {
        let visibleFrame = visibleFrame ?? fallbackVisibleFrame
        let targetWidth = visibleFrame.width - 2 * safeHorizontalMargin
        let clampedTargetWidth = min(targetWidth, visibleFrame.width)
        let layoutWidth = max(baseMinimumContentWidth, clampedTargetWidth)
        let width = min(layoutWidth * panelWidthScale, visibleFrame.width)
        return NSSize(width: width, height: contentHeight)
    }

    static func resolvedLeftColumnWidth(
        stored: Double,
        defaultWidth: CGFloat
    ) -> CGFloat {
        resolvedColumnWidth(stored: stored, defaultWidth: defaultWidth)
    }

    static func resolvedRightColumnWidth(
        stored: Double,
        defaultWidth: CGFloat
    ) -> CGFloat {
        resolvedColumnWidth(stored: stored, defaultWidth: defaultWidth)
    }

    static func resolvedColumnWidth(
        stored: Double,
        defaultWidth: CGFloat
    ) -> CGFloat {
        stored > 0 ? CGFloat(stored) : defaultWidth
    }

    static func clampedColumnWidths(
        left: CGFloat,
        right: CGFloat,
        totalInnerWidth: CGFloat,
        middleMin: CGFloat = middleColumnWidthMin,
        columnMin: CGFloat = columnWidthMin,
        chromeWidth: CGFloat = 0
    ) -> (left: CGFloat, right: CGFloat) {
        let available = max(totalInnerWidth - chromeWidth, columnMin * 2 + middleMin)
        var leftW = min(max(left, columnMin), available - columnMin - middleMin)
        var rightW = min(max(right, columnMin), available - leftW - middleMin)
        let middleW = available - leftW - rightW
        if middleW < middleMin {
            let deficit = middleMin - middleW
            if rightW > columnMin {
                let shave = min(deficit, rightW - columnMin)
                rightW -= shave
            }
            let remaining = middleMin - (available - leftW - rightW)
            if remaining > 0, leftW > columnMin {
                leftW = max(columnMin, leftW - remaining)
            }
        }
        return (leftW, rightW)
    }

    static func clampedLeftPlanFraction(_ value: Double) -> Double {
        let base = value == 0 ? defaultLeftPlanFraction : value
        return min(max(base, leftPlanFractionMin), leftPlanFractionMax)
    }

    /// 行向分隔：总高度减去 handle 后，上下两栏可分配高度。
    static func verticalSplitHeights(
        totalHeight: CGFloat,
        upperFraction: Double,
        handleHeight: CGFloat = columnResizeHandleWidth
    ) -> (upper: CGFloat, lower: CGFloat, stack: CGFloat) {
        let stack = max(totalHeight - handleHeight, 1)
        let clampedFraction = min(max(upperFraction, 0), 1)
        let upper = stack * clampedFraction
        return (upper, stack - upper, stack)
    }

    /// 将像素 delta 换算为比例增量；`stackHeight` 为 handle 以上/以下可分配总高度。
    static func fractionAfterVerticalDrag(
        current: Double,
        delta: CGFloat,
        stackHeight: CGFloat,
        clamp: (Double) -> Double
    ) -> Double {
        clamp(current + Double(delta / max(stackHeight, 1)))
    }

    static func resolvedLeftPlanFraction(defaults: UserDefaults = .standard) -> Double {
        let key = MalDazeDefaultsKeys.DashboardLayout.leftPlanFraction
        guard defaults.object(forKey: key) != nil else {
            return defaultLeftPlanFraction
        }
        return clampedLeftPlanFraction(defaults.double(forKey: key))
    }
}
