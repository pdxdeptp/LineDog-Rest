import AppKit
import Foundation

struct BreakRunMotionPolicy {
    struct Step {
        let origin: CGPoint
        let velocity: CGPoint
    }

    /// 每帧时间间隔（≈ 30 Hz），降低 WindowServer 唤醒但保留流畅弹跳。
    static let tickInterval: TimeInterval = 1.0 / 30.0

    /// 速度范围：PawPal 3.5~6.4 px/tick × 60 Hz × 0.7 缩放，单位为 pt/s。
    static let speedRange: ClosedRange<Double> = 147.0...268.8

    /// 转向检查间隔范围（秒）：PawPal 350~1200 ms。
    static let turnIntervalRange: ClosedRange<Double> = 0.35...1.2

    /// 转向触发概率（每次到达转向时刻时）：PawPal 0.45。
    static let turnProbability: Double = 0.45

    /// 窗口与屏幕边缘的最小距离（点），与 PawPal margin 8 保持一致。
    static let edgeMargin: CGFloat = 8

    static func shouldChooseNewVelocity(now: Date, nextTurnAt: Date, randomSample: Double) -> Bool {
        now >= nextTurnAt && randomSample < turnProbability
    }

    static func step(
        origin: CGPoint,
        windowSize: CGSize,
        visibleFrame: CGRect,
        velocity: CGPoint,
        elapsedSeconds: TimeInterval
    ) -> Step {
        let minX = visibleFrame.minX + edgeMargin
        let maxX = visibleFrame.maxX - windowSize.width - edgeMargin
        let minY = visibleFrame.minY + edgeMargin
        let maxY = visibleFrame.maxY - windowSize.height - edgeMargin
        var nextVelocity = velocity
        var nextX = origin.x + velocity.x * CGFloat(elapsedSeconds)
        var nextY = origin.y + velocity.y * CGFloat(elapsedSeconds)

        if nextX <= minX {
            nextX = minX
            nextVelocity.x = abs(nextVelocity.x)
        }
        if nextX >= maxX {
            nextX = maxX
            nextVelocity.x = -abs(nextVelocity.x)
        }
        if nextY <= minY {
            nextY = minY
            nextVelocity.y = abs(nextVelocity.y)
        }
        if nextY >= maxY {
            nextY = maxY
            nextVelocity.y = -abs(nextVelocity.y)
        }

        return Step(origin: CGPoint(x: nextX, y: nextY), velocity: nextVelocity)
    }
}

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
    private var lastTickDate: Date = .distantPast
    private var movementTimer: Timer?
    private var endDate: Date = .distantPast
    private var onComplete: (() -> Void)?

    // MARK: - Public interface

    /// 启动跑屏。`window` 为当前桌宠小窗（不扩全屏），`duration` 为整个休息时长。
    func start(window: NSWindow, duration: TimeInterval, onComplete: @escaping () -> Void) {
        stop()
        let now = Date()
        self.window = window
        self.onComplete = onComplete
        self.endDate = now.addingTimeInterval(duration)
        self.velocity = Self.chooseVelocity()
        self.nextTurnAt = now
        self.lastTickDate = now
        isRunning = true

        let t = Timer.scheduledTimer(withTimeInterval: BreakRunMotionPolicy.tickInterval, repeats: true) { [weak self] _ in
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
        lastTickDate = .distantPast
    }

    // MARK: - Movement algorithm (ported from PawPal)

    /// 随机生成速度矢量。移植自 PawPal `chooseBreakRunVelocity()`。
    private static func chooseVelocity() -> CGPoint {
        let speed = Double.random(in: BreakRunMotionPolicy.speedRange)
        let angle = Double.random(in: 0 ..< 2 * .pi)
        return CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
    }

    /// 每帧逻辑。移植自 PawPal `movePetForBreakRun()`。
    private func tick() {
        guard let win = window, !win.isDestroyed else {
            stop()
            return
        }

        let now = Date()

        // 休息时间到 → 通知完成
        if now >= endDate {
            let cb = onComplete
            stop()
            cb?()
            return
        }
        let elapsedSeconds = max(0, now.timeIntervalSince(lastTickDate))
        lastTickDate = now

        let bounds = win.frame

        // 找到当前窗口所在显示器的工作区（兼容多显示器）
        let workArea: NSRect
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(bounds.center) }) {
            workArea = screen.visibleFrame
        } else {
            workArea = NSScreen.main?.visibleFrame ?? bounds
        }

        // 随机转向（移植自 PawPal：到达转向时刻且满足概率则重新选速度方向）
        if now >= nextTurnAt {
            if BreakRunMotionPolicy.shouldChooseNewVelocity(
                now: now,
                nextTurnAt: nextTurnAt,
                randomSample: Double.random(in: 0...1)
            ) {
                velocity = Self.chooseVelocity()
            }
            nextTurnAt = now.addingTimeInterval(Double.random(in: BreakRunMotionPolicy.turnIntervalRange))
        }

        let step = BreakRunMotionPolicy.step(
            origin: bounds.origin,
            windowSize: bounds.size,
            visibleFrame: workArea,
            velocity: velocity,
            elapsedSeconds: elapsedSeconds
        )
        velocity = step.velocity
        win.setFrameOrigin(step.origin)
    }
}

// MARK: - Helpers

private extension NSRect {
    var center: NSPoint { NSPoint(x: midX, y: midY) }
}

private extension NSWindow {
    var isDestroyed: Bool { !isVisible && !isMiniaturized }
}
