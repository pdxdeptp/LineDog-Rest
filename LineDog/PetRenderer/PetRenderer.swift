import AppKit

/// 模块 3：桌宠渲染。单实例 + 底层描边视图，实现「白身黑边」暂停态。
protocol PetRendering: AnyObject {
    func install(in parent: NSView)
    func layoutPet(in bounds: CGRect, visualCenter: CGPoint, scale: CGFloat)
    func setDisplayMode(_ mode: PetDisplayMode)
}

final class PetRenderer: PetRendering {
    private let outlineImageView = NSImageView()
    private let imageView = NSImageView()

    init() {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        outlineImageView.imageScaling = .scaleProportionallyUpOrDown
    }

    func loadPetImage() {
        if let named = NSImage(named: "LineDogPet"), named.size.width > 0 {
            outlineImageView.image = named
            imageView.image = named
            return
        }
        let cfg = NSImage.SymbolConfiguration(pointSize: 128, weight: .regular)
        let sym = NSImage(systemSymbolName: "dog.fill", accessibilityDescription: "pet")?.withSymbolConfiguration(cfg)
        outlineImageView.image = sym
        imageView.image = sym
    }

    func install(in parent: NSView) {
        loadPetImage()
        // `contentTintColor` 仅对 layer-backed 的 NSImageView 生效；否则模板图/SF Symbol 可能完全不绘制（桌宠「真空」）。
        outlineImageView.wantsLayer = true
        imageView.wantsLayer = true
        outlineImageView.translatesAutoresizingMaskIntoConstraints = true
        imageView.translatesAutoresizingMaskIntoConstraints = true
        parent.addSubview(outlineImageView)
        parent.addSubview(imageView)
        setDisplayMode(.runningBlack)
    }

    func setDisplayMode(_ mode: PetDisplayMode) {
        switch mode {
        case .restingRed:
            outlineImageView.isHidden = true
            imageView.contentTintColor = .systemRed
        case .runningBlack:
            // 底层略大的白轮廓 + 上层黑身，形成白描边；单层深色在透明窗上易与桌面糊在一起。
            outlineImageView.isHidden = false
            outlineImageView.contentTintColor = .white
            imageView.contentTintColor = .black
        case .pausedWhiteOutline:
            outlineImageView.isHidden = false
            outlineImageView.contentTintColor = .black
            imageView.contentTintColor = .white
        case .thinking:
            outlineImageView.isHidden = false
            outlineImageView.contentTintColor = NSColor.systemIndigo.withAlphaComponent(0.45)
            imageView.contentTintColor = .systemIndigo
        }
    }

    /// 底层比前景略大：计时中作白描边，暂停态作黑边。
    private static let outlineScale: CGFloat = 1.14

    func layoutPet(in bounds: CGRect, visualCenter: CGPoint, scale: CGFloat) {
        let base = min(bounds.width, bounds.height) * 0.22
        let side = base * scale
        let outSide = side * Self.outlineScale
        imageView.frame = CGRect(
            x: visualCenter.x - side / 2,
            y: visualCenter.y - side / 2,
            width: side,
            height: side
        )
        outlineImageView.frame = CGRect(
            x: visualCenter.x - outSide / 2,
            y: visualCenter.y - outSide / 2,
            width: outSide,
            height: outSide
        )
    }
}
