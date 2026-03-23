import AppKit

/// 由 `WindowManager` 实现：在桌宠点击处弹出与菜单栏相同的 SwiftUI 面板。
protocol PetStageDeskMenuPresenter: AnyObject {
    func presentDeskMenu(from stage: PetStageView, anchorRect: NSRect)
    func presentSmartReminderInput(from stage: PetStageView, anchorRect: NSRect)
}

/// 唯一桌宠舞台：非休息时小窗内显示小狗，可拖动窗口；休息时**同一只**变红、移向中央并放大，背景渐暗，左下角倒计时。
final class PetStageView: NSView {
    private let dimView = NSView()
    private let pet = PetRenderer()
    private let countdownLabel = NSTextField(labelWithString: "5:00")

    private var tickTimer: Timer?
    private var restBeganAt: Date?
    /// 从黑狗当前位置移到屏中并放大；固定 60s，与距离无关。
    private let growDuration: TimeInterval = 60
    private let fadeOutDuration: TimeInterval = 3
    private var restTotal: TimeInterval = 5 * 60
    private var onRestComplete: (() -> Void)?

    /// 非休息时的配色（由 `WindowManager` 与「开始专注 / 停止计时」同步）。
    private var nonRestDisplayMode: PetDisplayMode = .runningBlack

    private static let idlePetSide: CGFloat = 100
    private static let edgeMargin: CGFloat = 16

    /// 非 nil 时：常态小窗整块可点；休息全屏时仅 `petHitRect` 可点：单击（略晚于系统双击间隔后）打开菜单，**双击**结束休息。
    weak var deskMenuPresenter: PetStageDeskMenuPresenter?
    private var petHitRect: NSRect = .zero
    /// 用户设置：休息全屏且红狗已到屏中后，是否拦截小狗区域外的点击（与 `AppViewModel.restBlocksClicksDuringRest` 同步）。
    /// 在「移向中央」动画进行期间（`growDuration` 内）始终对狗外区域透传，避免一开始就挡住正在进行的操作。
    var restUserBlocksClicksOutsidePet: Bool = true

    /// 常态小窗拖动结束后回写并持久化窗框（屏幕坐标）。
    var onIdlePetFramePersist: ((NSRect) -> Void)?
    /// 休息全屏时：在中央小狗上**双击**提前结束休息（与菜单里结束休息的逻辑一致）。
    var onRestPetDoubleClickEndRest: (() -> Void)?
    /// 每帧休息布局后由 `WindowManager` 同步 `NSWindow.ignoresMouseEvents`（仅靠根视图 `hitTest`→`nil` 在 `.screenSaver` 等层级上可能仍吞点击）。
    var onRestPhaseGeometryChanged: (() -> Void)?

    private var restSingleClickMenuWorkItem: DispatchWorkItem?
    /// 上一击在狗区域内的 `mouseUp`（系统 `clickCount` 在无法 key 的窗口上常为 1，用时间+距离补判双击）。
    private var restPetPriorMouseUpTimestamp: TimeInterval?
    private var restPetPriorMouseUpInWindow: NSPoint?

    private var idleMouseDownInWindow: NSPoint = .zero
    private var idleLastScreenMouse: NSPoint?
    /// 相对 `mouseDown` 的最大位移，用于区分点击弹出菜单与拖动窗口。
    private var idleMaxDragFromDown: CGFloat = 0
    /// 双击狗结束休息后，下一次 `mouseUp` 已落在常态分支；否则会误触发 `presentDeskMenu`。
    private var suppressDeskMenuOnNextIdleMouseUp = false

    /// 常态最后一次 `layoutIdlePet` 的小狗中心与绘制边长（`side = base * scale`，随用户拖动小窗而变）。
    private var idlePetVisualCenter: CGPoint = .zero
    private var idlePetVisualSide: CGFloat = 0
    /// `presentRest` 扩全屏前快照：屏幕坐标中心 + 黑狗实际边长（点）。
    private var restPendingStartCenterScreen: CGPoint?
    private var restPendingStartPetSide: CGFloat?
    /// 当前休息段动画用：全屏 `bounds` 下的起点中心与起点边长（在全屏 `base` 下插值到 `endSide`，保证从小到大）。
    private var restArcStartCenterLocal: CGPoint?
    private var restArcStartPetSide: CGFloat?

    var isInRestPhase: Bool { restBeganAt != nil }

    /// 红狗「移到屏中」动画是否已结束（与 `hitTest` / 休息穿透策略一致）。
    var restApproachAnimationComplete: Bool {
        guard let t = restBeganAt else { return true }
        return Date().timeIntervalSince(t) >= growDuration
    }

    /// `petHitRect` 转为窗口基坐标，供与 `NSEvent.mouseLocation`（屏幕坐标）对照。
    var petHitRectInWindowBaseCoordinates: NSRect {
        convert(petHitRect, to: nil)
    }

    /// 与左键打开桌宠菜单相同的锚区（快捷键 `⌘⇧'` 用）。
    var deskMenuShortcutAnchorRect: NSRect {
        if restBeganAt != nil {
            return petHitRect
        }
        return bounds.insetBy(dx: 4, dy: 4)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        dimView.wantsLayer = true
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0).cgColor
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        pet.install(in: self)

        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        countdownLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 96, weight: .semibold)
        countdownLabel.textColor = .white
        countdownLabel.alignment = .left
        countdownLabel.isEditable = false
        countdownLabel.isSelectable = false
        countdownLabel.drawsBackground = false
        countdownLabel.isBordered = false
        countdownLabel.wantsLayer = true
        countdownLabel.layer?.shadowColor = NSColor.black.cgColor
        countdownLabel.layer?.shadowOffset = CGSize(width: 0, height: 1)
        countdownLabel.layer?.shadowRadius = 6
        countdownLabel.layer?.shadowOpacity = 0.85
        countdownLabel.isHidden = true
        addSubview(countdownLabel)
        NSLayoutConstraint.activate([
            countdownLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            countdownLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -32)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 首帧 layout 时常尚未拿到最终 bounds，过早 return 会导致 imageView 一直为 .zero，桌宠永久不画。
        needsLayout = true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard deskMenuPresenter != nil else { return nil }
        // 文档称 `point` 在父视图坐标系；与 `mouseDown` 一致时，应得到与 `NSEvent.locationInWindow` 相同的**窗口基坐标**再 `convert(_, from: nil)` 到局部。
        let locationInWindow: NSPoint
        if let sv = superview {
            locationInWindow = sv.convert(point, to: nil)
        } else {
            locationInWindow = point
        }
        let local = convert(locationInWindow, from: nil)
        guard bounds.contains(local) else { return nil }
        if let start = restBeganAt {
            let elapsed = Date().timeIntervalSince(start)
            let approachComplete = elapsed >= growDuration
            let passThroughOutsidePet = !restUserBlocksClicksOutsidePet || !approachComplete
            if passThroughOutsidePet, !petHitRect.contains(local) {
                return nil
            }
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        guard deskMenuPresenter != nil else { return }
        let pt = convert(event.locationInWindow, from: nil)
        if restBeganAt != nil {
            window?.makeKeyAndOrderFront(nil)
            guard petHitRect.contains(pt) else { return }
            restPetClearStalePriorMouseUpIfNeeded(event.timestamp)
            if restPetDetectDoubleClickFromPriorMouseUp(mouseDown: event) {
                return
            }
            if event.clickCount >= 2 {
                performRestPetDoubleClickDismiss()
                return
            }
            return
        }
        suppressDeskMenuOnNextIdleMouseUp = false
        idleMouseDownInWindow = event.locationInWindow
        idleLastScreenMouse = NSEvent.mouseLocation
        idleMaxDragFromDown = 0
    }

    override func mouseDragged(with event: NSEvent) {
        guard deskMenuPresenter != nil, restBeganAt == nil, let win = window else { return }
        let cur = event.locationInWindow
        idleMaxDragFromDown = max(
            idleMaxDragFromDown,
            hypot(cur.x - idleMouseDownInWindow.x, cur.y - idleMouseDownInWindow.y)
        )
        guard idleMaxDragFromDown >= 4, let lastScreen = idleLastScreenMouse else { return }
        let nowScreen = NSEvent.mouseLocation
        var f = win.frame
        f.origin.x += nowScreen.x - lastScreen.x
        f.origin.y += nowScreen.y - lastScreen.y
        win.setFrame(f, display: true)
        idleLastScreenMouse = nowScreen
    }

    override func rightMouseDown(with event: NSEvent) {
        guard deskMenuPresenter != nil else { return }
        let pt = convert(event.locationInWindow, from: nil)
        let anchor: NSRect
        if restBeganAt != nil {
            guard petHitRect.contains(pt) else { return }
            anchor = petHitRect
        } else {
            anchor = bounds.insetBy(dx: 4, dy: 4)
            guard anchor.contains(pt) else { return }
        }
        deskMenuPresenter?.presentSmartReminderInput(from: self, anchorRect: anchor)
    }

    override func mouseUp(with event: NSEvent) {
        guard deskMenuPresenter != nil else { return }
        let pt = convert(event.locationInWindow, from: nil)
        if restBeganAt != nil {
            guard petHitRect.contains(pt) else { return }
            guard event.clickCount < 2 else { return }
            if event.clickCount == 1 {
                restSingleClickMenuWorkItem?.cancel()
                restPetPriorMouseUpTimestamp = event.timestamp
                restPetPriorMouseUpInWindow = event.locationInWindow
                let work = DispatchWorkItem { [weak self] in
                    guard let self, self.restBeganAt != nil else { return }
                    self.restSingleClickMenuWorkItem = nil
                    self.deskMenuPresenter?.presentDeskMenu(from: self, anchorRect: self.petHitRect)
                }
                restSingleClickMenuWorkItem = work
                let delay = NSEvent.doubleClickInterval
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            }
            return
        }
        if suppressDeskMenuOnNextIdleMouseUp {
            suppressDeskMenuOnNextIdleMouseUp = false
            idleLastScreenMouse = nil
            idleMaxDragFromDown = 0
            return
        }
        defer {
            idleLastScreenMouse = nil
            idleMaxDragFromDown = 0
        }
        if idleMaxDragFromDown < 4 {
            deskMenuPresenter?.presentDeskMenu(from: self, anchorRect: bounds.insetBy(dx: 4, dy: 4))
        } else if let win = window {
            onIdlePetFramePersist?(win.frame)
        }
    }

    func applyNonRestPetDisplayMode(_ mode: PetDisplayMode) {
        nonRestDisplayMode = mode
        if restBeganAt == nil {
            pet.setDisplayMode(mode)
        }
    }

    func beginRestCycle(total restSeconds: TimeInterval, onComplete: @escaping () -> Void) {
        suppressDeskMenuOnNextIdleMouseUp = false
        restSingleClickMenuWorkItem?.cancel()
        restSingleClickMenuWorkItem = nil
        restPetClearDoubleClickTracking()
        stopTickTimer()
        onRestComplete = onComplete
        restTotal = restSeconds

        layoutSubtreeIfNeeded()
        let b = bounds
        if let sp = restPendingStartCenterScreen, let win = window {
            let inWin = win.convertPoint(fromScreen: sp)
            restArcStartCenterLocal = convert(inWin, from: nil)
            restPendingStartCenterScreen = nil
        } else {
            restArcStartCenterLocal = petCornerCenter(in: b)
        }
        restArcStartPetSide = restPendingStartPetSide
        restPendingStartPetSide = nil

        restBeganAt = Date()
        countdownLabel.isHidden = false
        pet.setDisplayMode(.restingRed)
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0).cgColor
        layoutSubtreeIfNeeded()
        applyRestPhase(easedProgress(at: 0))
        startTickTimer()
    }

    /// 中断休息并回到右下角常态（不调用 `onRestComplete`；由 `WindowManager` 负责 `pendingDismiss`）。
    func cancelToIdle() {
        // 勿在此重置 `suppressDeskMenuOnNextIdleMouseUp`：`performRestPetDoubleClickDismiss` 先设 true 再调
        // `dismissRestImmediately`→本方法，若清掉则紧随其后的 `mouseUp` 会误开桌宠菜单。
        restSingleClickMenuWorkItem?.cancel()
        restSingleClickMenuWorkItem = nil
        restPetClearDoubleClickTracking()
        stopTickTimer()
        restBeganAt = nil
        restPendingStartCenterScreen = nil
        restPendingStartPetSide = nil
        restArcStartCenterLocal = nil
        restArcStartPetSide = nil
        onRestComplete = nil
        countdownLabel.isHidden = true
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0).cgColor
        layoutIdlePet()
    }

    override func layout() {
        super.layout()
        if restBeganAt == nil {
            layoutIdlePet()
        } else {
            let elapsed = Date().timeIntervalSince(restBeganAt!)
            applyRestPhase(easedProgress(at: elapsed))
        }
    }

    private func easedProgress(at elapsed: TimeInterval) -> CGFloat {
        if elapsed <= growDuration {
            let t = CGFloat(elapsed / growDuration)
            return t * t * (3 - 2 * t)
        }
        if elapsed >= restTotal - fadeOutDuration {
            let u = (elapsed - (restTotal - fadeOutDuration)) / fadeOutDuration
            let t = CGFloat(min(1, max(0, u)))
            let p = 1 - t
            return p * p * (3 - 2 * p)
        }
        return 1
    }

    private func petCornerCenter(in b: NSRect) -> CGPoint {
        let side = Self.idlePetSide
        let m = Self.edgeMargin
        let fallback = CGPoint(x: b.maxX - m - side / 2, y: b.minY + m + side / 2)
        guard let win = window,
              let menuBarScreen = MenuBarNSScreen.screen ?? NSScreen.screens.first else {
            return fallback
        }
        // 用「窗框 ∩ 菜单栏屏可见区」的全局坐标 + `convertPoint(fromScreen:)`，避免双屏下对整屏 rect 做
        // `convertFromScreen` 时得到错误局部坐标，把小狗画到视图外。
        let overlap = win.frame.intersection(menuBarScreen.visibleFrame)
        guard overlap.width > 32, overlap.height > 32 else {
            return fallback
        }
        let gx = overlap.maxX - m - side / 2
        let gy = overlap.minY + m + side / 2
        let inWindow = win.convertPoint(fromScreen: NSPoint(x: gx, y: gy))
        let local = convert(inWindow, from: nil)
        let pad = side / 2 + m
        let x = min(max(local.x, pad), b.maxX - pad)
        let y = min(max(local.y, pad), b.maxY - pad)
        return CGPoint(x: x, y: y)
    }

    /// - Parameter hitPadding: 休息动画全程可点区域略大于绘制，避免「点到了图但不在 rect 里」。
    private static func petHitRect(center: CGPoint, scale: CGFloat, in b: NSRect, hitPadding: CGFloat) -> NSRect {
        let base = min(b.width, b.height) * 0.22
        let side = base * scale
        return NSRect(
            x: center.x - side / 2 - hitPadding,
            y: center.y - side / 2 - hitPadding,
            width: side + 2 * hitPadding,
            height: side + 2 * hitPadding
        )
    }

    private func layoutIdlePet() {
        let b = bounds
        guard b.width > 1, b.height > 1 else { return }
        let center: CGPoint
        let scale: CGFloat
        let base = min(b.width, b.height) * 0.22
        if b.width < 400 {
            // 常态小窗：桌宠居中，整块小窗与菜单栏角标大致对齐。
            center = CGPoint(x: b.midX, y: b.midY)
            scale = Self.idlePetSide / max(base, 1)
            petHitRect = b.insetBy(dx: 4, dy: 4)
        } else {
            // 兜底：若窗框异常偏大仍按「全屏右下角」算（不应在常态出现）。
            center = petCornerCenter(in: b)
            scale = Self.idlePetSide / max(base, 1)
            petHitRect = Self.petHitRect(center: center, scale: scale, in: b, hitPadding: 16)
        }
        pet.layoutPet(in: b, visualCenter: center, scale: scale)
        idlePetVisualCenter = center
        idlePetVisualSide = base * scale
        if restBeganAt == nil {
            pet.setDisplayMode(nonRestDisplayMode)
        }
    }

    /// 在 `WindowManager` 把桌宠窗扩到菜单栏屏全屏**之前**调用，使红狗从黑狗当时位置与大小起画。
    func snapshotRestPetStartStateBeforeExpandingToRest() {
        guard restBeganAt == nil, let win = window else { return }
        let local = idlePetVisualCenter
        let inWin = convert(local, to: nil)
        let r = win.convertToScreen(NSRect(x: inWin.x, y: inWin.y, width: 0, height: 0))
        restPendingStartCenterScreen = r.origin
        restPendingStartPetSide = idlePetVisualSide
    }

    private func applyRestPhase(_ p: CGFloat) {
        defer { onRestPhaseGeometryChanged?() }
        let b = bounds
        guard b.width > 1, b.height > 1 else { return }
        guard let start = restBeganAt else { return }

        let elapsed = Date().timeIntervalSince(start)

        if elapsed >= restTotal {
            stopTickTimer()
            let done = onRestComplete
            onRestComplete = nil
            restBeganAt = nil
            restArcStartCenterLocal = nil
            restArcStartPetSide = nil
            restPetClearDoubleClickTracking()
            restSingleClickMenuWorkItem?.cancel()
            restSingleClickMenuWorkItem = nil
            countdownLabel.isHidden = true
            dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0).cgColor
            done?()
            layoutIdlePet()
            return
        }

        updateCountdown(remaining: max(0, restTotal - elapsed))

        let dimAlpha = 0.58 * p
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(dimAlpha).cgColor

        let targetCenter = CGPoint(x: b.midX, y: b.midY)
        let startCenter = restArcStartCenterLocal ?? petCornerCenter(in: b)
        let pos = CGPoint(
            x: startCenter.x + (targetCenter.x - startCenter.x) * p,
            y: startCenter.y + (targetCenter.y - startCenter.y) * p
        )
        let base = min(b.width, b.height) * 0.22
        // 用边长插值：黑狗在常态下的像素边长 → 全屏目标边长；避免「小窗 scale 数值」直接套在全屏 base 上变成从大到小。
        let startSide = restArcStartPetSide ?? Self.idlePetSide
        let nominalEndSide = base * 1.15
        let endSide = max(nominalEndSide, startSide * 1.02)
        let side = startSide + (endSide - startSide) * p
        let scale = side / max(base, 1)
        petHitRect = Self.petHitRect(center: pos, scale: scale, in: b, hitPadding: 52)
        pet.layoutPet(in: b, visualCenter: pos, scale: scale)
    }

    private func restPetClearDoubleClickTracking() {
        restPetPriorMouseUpTimestamp = nil
        restPetPriorMouseUpInWindow = nil
    }

    private func restPetClearStalePriorMouseUpIfNeeded(_ now: TimeInterval) {
        guard let t0 = restPetPriorMouseUpTimestamp else { return }
        if now - t0 > NSEvent.doubleClickInterval + 0.12 {
            restPetClearDoubleClickTracking()
        }
    }

    /// 在 `clickCount` 无法变成 2 时，用「上一次狗区内 mouseUp → 本次 mouseDown」的时间与位移判定双击。
    private func restPetDetectDoubleClickFromPriorMouseUp(mouseDown event: NSEvent) -> Bool {
        guard let t0 = restPetPriorMouseUpTimestamp,
              let p0 = restPetPriorMouseUpInWindow else { return false }
        let dt = event.timestamp - t0
        guard dt <= NSEvent.doubleClickInterval + 0.12 else { return false }
        let p1 = event.locationInWindow
        guard hypot(p1.x - p0.x, p1.y - p0.y) <= 48 else { return false }
        performRestPetDoubleClickDismiss()
        return true
    }

    private func performRestPetDoubleClickDismiss() {
        restPetClearDoubleClickTracking()
        restSingleClickMenuWorkItem?.cancel()
        restSingleClickMenuWorkItem = nil
        suppressDeskMenuOnNextIdleMouseUp = true
        onRestPetDoubleClickEndRest?()
    }

    private func updateCountdown(remaining: TimeInterval) {
        let totalSecs = max(0, Int(floor(remaining)))
        let m = totalSecs / 60
        let s = totalSecs % 60
        countdownLabel.stringValue = String(format: "%d:%02d", m, s)
    }

    private func startTickTimer() {
        stopTickTimer()
        // 60Hz 会让主线程与 WindowServer 在整段休息霸屏期间持续重绘；15Hz 对 60s 位移动画仍足够顺滑。
        let t = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.restBeganAt else { return }
                let elapsed = Date().timeIntervalSince(start)
                self.applyRestPhase(self.easedProgress(at: elapsed))
            }
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func stopTickTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    deinit {
        stopTickTimer()
    }
}
