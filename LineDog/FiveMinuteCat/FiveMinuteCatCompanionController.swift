import AppKit

/// 菜单触发的 5 分钟小猫陪伴：独立 `NSWindow`，与 `WindowManager` / `PetStageView` 无类型依赖；通过通知与 `UserDefaults` 对齐小狗屏幕位置。
@MainActor
final class FiveMinuteCatCompanionController {
    static let presenceDuration: TimeInterval = 5 * 60
    private static let fadeOutDuration: TimeInterval = 3
    private static let catSide: CGFloat = 56
    private static let gapFromDog: CGFloat = 8
    /// 与 `WindowManager` 持久化键一致，仅用于首帧定位（随后跟通知更新）。
    private static let dogOriginXKey = "LineDog.idlePetOriginX"
    private static let dogOriginYKey = "LineDog.idlePetOriginY"
    private static let dogWidth: CGFloat = 132
    private static let dogHeight: CGFloat = 132

    var onActiveChanged: ((Bool) -> Void)?

    private var catWindow: NSWindow?
    private var fadeWorkItem: DispatchWorkItem?
    private var frameObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var lastDogScreenFrame: NSRect = .zero

    func start() {
        cancel()
        lastDogScreenFrame = dogFrameFromDefaults()
        observeDogFrame()
        observeScreens()
        installCatWindow()
        repositionCatWindow()
        catWindow?.alphaValue = 1
        catWindow?.orderFrontRegardless()
        onActiveChanged?(true)

        let fadeDelay = Self.presenceDuration - Self.fadeOutDuration
        let fade = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.runFadeOutAndDismiss()
            }
        }
        fadeWorkItem = fade
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.1, fadeDelay), execute: fade)
    }

    func cancel() {
        fadeWorkItem?.cancel()
        fadeWorkItem = nil
        if let o = frameObserver {
            NotificationCenter.default.removeObserver(o)
            frameObserver = nil
        }
        if let o = screenObserver {
            NotificationCenter.default.removeObserver(o)
            screenObserver = nil
        }
        catWindow?.orderOut(nil)
        catWindow = nil
        onActiveChanged?(false)
    }

    private func runFadeOutAndDismiss() {
        fadeWorkItem = nil
        guard let win = catWindow else {
            cancel()
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Self.fadeOutDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                self?.cancel()
            }
        })
    }

    private func observeDogFrame() {
        frameObserver = NotificationCenter.default.addObserver(
            forName: LineDogBroadcastNotifications.idlePetScreenFrameChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                guard let self,
                      let v = note.userInfo?[LineDogBroadcastNotifications.idlePetScreenFrameUserInfoKey] as? NSValue
                else { return }
                self.lastDogScreenFrame = v.rectValue
                self.repositionCatWindow()
            }
        }
    }

    private func observeScreens() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repositionCatWindow()
            }
        }
    }

    private func dogFrameFromDefaults() -> NSRect {
        let d = UserDefaults.standard
        guard d.object(forKey: Self.dogOriginXKey) != nil,
              d.object(forKey: Self.dogOriginYKey) != nil
        else {
            return Self.fallbackDogFrame()
        }
        let x = d.double(forKey: Self.dogOriginXKey)
        let y = d.double(forKey: Self.dogOriginYKey)
        return NSRect(x: x, y: y, width: Self.dogWidth, height: Self.dogHeight)
    }

    private static func fallbackDogFrame() -> NSRect {
        guard let s = MenuBarNSScreen.screen ?? NSScreen.screens.first else {
            return NSRect(x: 400, y: 200, width: dogWidth, height: dogHeight)
        }
        let vf = s.visibleFrame
        let m: CGFloat = 10
        return NSRect(
            x: vf.maxX - dogWidth - m,
            y: vf.minY + m,
            width: dogWidth,
            height: dogHeight
        )
    }

    private func installCatWindow() {
        let f = NSRect(x: 0, y: 0, width: Self.catSide, height: Self.catSide)
        let win = NSWindow(
            contentRect: f,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: MenuBarNSScreen.screen ?? NSScreen.screens.first
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 5)
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.isReleasedWhenClosed = false
        win.ignoresMouseEvents = true
        win.hidesOnDeactivate = false

        let iv = NSImageView(frame: NSRect(origin: .zero, size: f.size))
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "小猫")
        iv.contentTintColor = .labelColor
        iv.wantsLayer = true
        iv.layer?.shadowColor = NSColor.black.cgColor
        iv.layer?.shadowOffset = CGSize(width: 0, height: -0.5)
        iv.layer?.shadowRadius = 2
        iv.layer?.shadowOpacity = 0.35

        win.contentView = iv
        catWindow = win
    }

    private func repositionCatWindow() {
        guard let win = catWindow else { return }
        let dog = lastDogScreenFrame
        guard dog.width > 1, dog.height > 1 else { return }
        let catF = Self.catFrame(leftOfDog: dog)
        win.setFrame(catF, display: true)
        win.contentView?.frame = NSRect(origin: .zero, size: catF.size)
    }

    /// 优先放在小狗左侧；若超出所有屏左缘则改到小狗右侧。
    private static func catFrame(leftOfDog dog: NSRect) -> NSRect {
        let union = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        let side = catSide
        let gap = gapFromDog
        var x = dog.minX - gap - side
        var y = dog.midY - side / 2
        var cat = NSRect(x: x, y: y, width: side, height: side)

        if cat.minX < union.minX - 0.5 {
            x = dog.maxX + gap
            cat.origin.x = x
        }

        cat.origin.y = min(max(cat.minY, union.minY), union.maxY - side)
        cat.origin.x = min(max(cat.minX, union.minX), union.maxX - side)
        return cat
    }
}
