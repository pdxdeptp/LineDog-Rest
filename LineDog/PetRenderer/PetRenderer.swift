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
            // 与暂停态相同：底层描边 + 上层填色。单层 + labelColor 在透明全屏窗上常和桌面糊在一起，表现为「小狗没了」。
            outlineImageView.isHidden = false
            outlineImageView.contentTintColor = .black
            imageView.contentTintColor = .labelColor
        case .pausedWhiteOutline:
            outlineImageView.isHidden = false
            outlineImageView.contentTintColor = .black
            imageView.contentTintColor = .white
        }
    }

    /// 暂停态描边比前景略大，形成黑边。
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
