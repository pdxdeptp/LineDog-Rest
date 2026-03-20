import Foundation

/// 计时引擎对外的统一状态（手动 / 自动模式最终都映射到此枚举）。
enum TimeState: Equatable {
    /// 未开始任何模式。
    case idle
    /// 手动模式：25 分钟专注倒计时。
    case working(remaining: TimeInterval)
    /// 两种模式：5 分钟休息倒计时（与霸屏联动）。
    case resting(remaining: TimeInterval)
    /// 自动模式：等待下一个整点或半点。
    case autoWatching(nextAnchor: Date)
}
