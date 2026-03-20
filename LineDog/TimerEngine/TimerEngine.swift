import Foundation

/// 模块 1：计时核心协议。具体策略（手动番茄 / 系统锚定）各自实现，对外只派发 `TimeState`。
protocol TimerEngine: AnyObject {
    var onStateChange: ((TimeState) -> Void)? { get set }
    func start()
    func stop()
}
