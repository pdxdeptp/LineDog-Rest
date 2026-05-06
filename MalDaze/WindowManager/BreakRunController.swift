import AppKit
import Foundation

/// 跑屏休息模式引擎：将桌宠小窗在屏幕工作区内随机弹跳漫游。
///
/// 算法直接移植自 PawPal（MIT 许可）：
///   `startBreakRun` / `movePetForBreakRun` / `chooseBreakRunVelocity`
///   来源：https://github.com/zebangeth/PawPal/blob/main/src/main/main.ts
///
/// 速度缩放至 PawPal 原值的 70%（约 150~260 px/s），在 macOS 视网膜屏上更自然。
@MainActor
final class BreakRunController {

    // MARK: - Public state

    private(set) var isRunning = false

    // MARK: - Private state

    private weak var window: NSWindow?
    private var velocity: CGPoint = .zero
    private var nextTurnAt: Date = .distantPast
    private var movementTimer: Timer?
    private var endDate: Date = .distantPast
    private var onComplete: (() -> Void)?

    /// 每帧时间间隔（≈ 60 Hz），与 PawPal BREAK_RUN_TICK_MS = 16 对应。
    private static let tickInterval: TimeInterval = 1.0 / 60.0

    /// 速度范围：PawPal 3.5~6.4 px/tick × 0.7 缩放。
    private static let speedRange: ClosedRange<Double> = 2.45...4.48

    /// 转向检查间隔范围（秒）：PawPal 350~1200 ms。
    private static let turnIntervalRange: ClosedRange<Double> = 0.35...1.2

    /// 转向触发概率（每次到达转向时刻时）：PawPal 0.45。
    private static let turnProbability: Double = 0.45

    /// 窗口与屏幕边缘的最小距离（点），与 PawPal margin 8 保持一致。
    private static let edgeMargin: CGFloat = 8

    // MARK: - Public interface

    /// 启动跑屏。`window` 为当前桌宠小窗（不扩全屏），`duration` 为整个休息时长。
    func start(window: NSWindow, duration: TimeInterval, onComplete: @escaping () -> Void) {
        stop()
        self.window = window
        self.onComplete = onComplete
        self.endDate = Date().addingTimeInterval(duration)
        self.velocity = Self.chooseVelocity()
        self.nextTurnAt = Date()
        isRunning = true

        let t = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        movementTimer = t
    }

    /// 强制停止（用户提前结束 / 应用退出）。不触发 onComplete。
    func stop() {
        movementTimer?.invalidate()
        movementTimer = nil
        isRunning = false
        window = nil
        onComplete = nil
    }

    // MARK: - Movement algorithm (ported from PawPal)

    /// 随机生成速度矢量。移植自 PawPal `chooseBreakRunVelocity()`。
    private static func chooseVelocity() -> CGPoint {
        let speed = Double.random(in: speedRange)
        let angle = Double.random(in: 0 ..< 2 * .pi)
        return CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
    }

    /// 每帧逻辑。移植自 PawPal `movePetForBreakRun()`。
    private func tick() {
        guard let win = window, !win.isDestroyed else {
            stop()
            return
        }

        // 休息时间到 → 通知完成
        if Date() >= endDate {
            let cb = onComplete
            stop()
            cb?()
            return
        }

        let bounds = win.frame

        // 找到当前窗口所在显示器的工作区（兼容多显示器）
        let workArea: NSRect
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(bounds.center) }) {
            workArea = screen.visibleFrame
        } else {
            workArea = NSScreen.main?.visibleFrame ?? bounds
        }

        let winW = bounds.width
        let winH = bounds.height
        let minX = workArea.minX + Self.edgeMargin
        let maxX = workArea.maxX - winW - Self.edgeMargin
        let minY = workArea.minY + Self.edgeMargin
        let maxY = workArea.maxY - winH - Self.edgeMargin

        // 随机转向（移植自 PawPal：到达转向时刻且满足概率则重新选速度方向）
        let now = Date()
        if now >= nextTurnAt {
            if Double.random(in: 0...1) < Self.turnProbability {
                velocity = Self.chooseVelocity()
            }
            nextTurnAt = now.addingTimeInterval(Double.random(in: Self.turnIntervalRange))
        }

        // 计算下一位置
        var nextX = bounds.minX + velocity.x
        var nextY = bounds.minY + velocity.y

        // 边界反弹（移植自 PawPal）
        if nextX <= minX {
            nextX = minX
            velocity.x = abs(velocity.x)
        }
        if nextX >= maxX {
            nextX = maxX
            velocity.x = -abs(velocity.x)
        }
        if nextY <= minY {
            nextY = minY
            velocity.y = abs(velocity.y)
        }
        if nextY >= maxY {
            nextY = maxY
            velocity.y = -abs(velocity.y)
        }

        win.setFrameOrigin(NSPoint(x: nextX, y: nextY))
    }
}

// MARK: - Helpers

private extension NSRect {
    var center: NSPoint { NSPoint(x: midX, y: midY) }
}

private extension NSWindow {
    var isDestroyed: Bool { !isVisible && !isMiniaturized }
}
