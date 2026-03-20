import Foundation
@testable import LineDog

/// 镜像 `WindowManager.presentRest` / `dismissRestImmediately` 的回调顺序，不创建真实窗口。
final class MockWindowManager: WindowManaging {
    private(set) var dismissCount = 0
    private(set) var presentCount = 0
    private(set) var lastPresentDuration: TimeInterval?
    private(set) var idleModesApplied: [PetDisplayMode] = []

    private var pendingUserDismiss: (() -> Void)?

    func dismissRestImmediately() {
        let cb = pendingUserDismiss
        pendingUserDismiss = nil
        cb?()
        dismissCount += 1
    }

    func presentRest(duration: TimeInterval, onDismissed: @escaping () -> Void) {
        dismissRestImmediately()
        pendingUserDismiss = onDismissed
        lastPresentDuration = duration
        presentCount += 1
    }

    func applyIdlePetDisplayMode(_ mode: PetDisplayMode) {
        idleModesApplied.append(mode)
    }

    func bindDeskPetMenu(viewModel: AppViewModel?) {}

    func setRestBlocksClicks(_ blocks: Bool) {}

    /// 对应真实流程里休息动画结束、`finishRestCycle` 调用用户传入的 `onDismissed`。
    func testing_simulateRestPresentationFinished() {
        let cb = pendingUserDismiss
        pendingUserDismiss = nil
        cb?()
    }
}
