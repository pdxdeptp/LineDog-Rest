import AppKit

/// 由 `WindowManager` 实现：在桌宠点击处弹出与菜单栏相同的 SwiftUI 面板。
protocol PetStageDeskMenuPresenter: AnyObject {
    func presentDeskMenu(from stage: PetStageView, anchorRect: NSRect)
}

/// 唯一桌宠舞台：非休息时小窗内显示小狗，可拖动窗口；休息时**同一只**变红、移向中央并放大，背景渐暗，左下角倒计时。
final class PetStageView: NSView {
    private let dimView = NSView()
    private let pet = PetRenderer()
    private let countdownLabel = NSTextField(labelWithString: "5:00")

    private var tickTimer: Timer?
    private var restBeganAt: Date?
    private let growDuration: TimeInterval = 45
    private let fadeOutDuration: TimeInterval = 3
    private var restTotal: TimeInterval = 5 * 60
    private var onRestComplete: (() -> Void)?

    /// 非休息时的配色（由 `WindowManager` 与「开始专注 / 停止计时」同步）。
    private var nonRestDisplayMode: PetDisplayMode = .runningBlack

    private static let idlePetSide: CGFloat = 100
    private static let edgeMargin: CGFloat = 16

    /// 非 nil 时：常态小窗整块可点；休息全屏时仅 `petHitRect`（桌宠区域）打开菜单，其余区域仍挡点击（霸屏）。
    weak var deskMenuPresenter: PetStageDeskMenuPresenter?
    private var petHitRect: NSRect = .zero

    /// 常态小窗拖动结束后回写并持久化窗框（屏幕坐标）。
    var onIdlePetFramePersist: ((NSRect) -> Void)?

    private var idleMouseDownInWindow: NSPoint = .zero
    private var idleLastScreenMouse: NSPoint?
    /// 相对 `mouseDown` 的最大位移，用于区分点击弹出菜单与拖动窗口。
    private var idleMaxDragFromDown: CGFloat = 0

    var isInRestPhase: Bool { restBeganAt != nil }

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

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard deskMenuPresenter != nil, bounds.contains(point) else { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        guard deskMenuPresenter != nil else { return }
        let pt = convert(event.locationInWindow, from: nil)
        if restBeganAt != nil {
            guard petHitRect.contains(pt) else { return }
            deskMenuPresenter?.presentDeskMenu(from: self, anchorRect: petHitRect)
            return
        }
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

    override func mouseUp(with event: NSEvent) {
        guard deskMenuPresenter != nil, restBeganAt == nil else { return }
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
        stopTickTimer()
        onRestComplete = onComplete
        restTotal = restSeconds
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
        stopTickTimer()
        restBeganAt = nil
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

    private static func petHitRect(center: CGPoint, scale: CGFloat, in b: NSRect) -> NSRect {
        let base = min(b.width, b.height) * 0.22
        let side = base * scale
        let padding: CGFloat = 16
        return NSRect(
            x: center.x - side / 2 - padding,
            y: center.y - side / 2 - padding,
            width: side + 2 * padding,
            height: side + 2 * padding
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
            petHitRect = Self.petHitRect(center: center, scale: scale, in: b)
        }
        pet.layoutPet(in: b, visualCenter: center, scale: scale)
        if restBeganAt == nil {
            pet.setDisplayMode(nonRestDisplayMode)
        }
    }

    private func applyRestPhase(_ p: CGFloat) {
        let b = bounds
        guard b.width > 1, b.height > 1 else { return }
        guard let start = restBeganAt else { return }

        let elapsed = Date().timeIntervalSince(start)

        if elapsed >= restTotal {
            stopTickTimer()
            let done = onRestComplete
            onRestComplete = nil
            restBeganAt = nil
            countdownLabel.isHidden = true
            dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0).cgColor
            done?()
            layoutIdlePet()
            return
        }

        updateCountdown(remaining: max(0, restTotal - elapsed))

        let dimAlpha = 0.58 * p
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(dimAlpha).cgColor

        let corner = petCornerCenter(in: b)
        let center = CGPoint(x: b.midX, y: b.midY)
        let pos = CGPoint(
            x: corner.x + (center.x - corner.x) * p,
            y: corner.y + (center.y - corner.y) * p
        )
        let base = min(b.width, b.height) * 0.22
        let minScale = Self.idlePetSide / max(base, 1)
        let maxScale: CGFloat = 1.15
        let scale = minScale + (maxScale - minScale) * p
        petHitRect = Self.petHitRect(center: pos, scale: scale, in: b)
        pet.layoutPet(in: b, visualCenter: pos, scale: scale)
    }

    private func updateCountdown(remaining: TimeInterval) {
        let totalSecs = max(0, Int(floor(remaining)))
        let m = totalSecs / 60
        let s = totalSecs % 60
        countdownLabel.stringValue = String(format: "%d:%02d", m, s)
    }

    private func startTickTimer() {
        stopTickTimer()
        let t = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
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
