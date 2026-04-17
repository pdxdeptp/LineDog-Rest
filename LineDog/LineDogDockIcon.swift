import AppKit

/// 与 `PetRenderer` 常态「计时中」一致：优先 `LineDogPet`（模板叠白边 + 黑身），否则 `dog.fill` 同样叠层。用于 Dock，不改变桌宠绘制逻辑。
enum LineDogDockIcon {
    /// 与 `PetRenderer.outlineScale` 一致。
    private static let outlineScale: CGFloat = 1.14

    /// 生成 Dock / `NSApplication.applicationIconImage` 用位图（正方形）。
    static func makeImage(pixelSize: CGFloat = 512) -> NSImage {
        if let named = NSImage(named: "LineDogPet"), named.size.width > 0 {
            return compositeTemplatePet(named, pixelSize: pixelSize)
        }
        return compositeSystemDogFill(pixelSize: pixelSize)
    }

    /// 与 `PetRenderer` + `LineDogPet` 模板一致：同一张图两层，外白内黑，边长比 `outlineScale`。
    private static func compositeTemplatePet(_ template: NSImage, pixelSize: CGFloat) -> NSImage {
        let whiteLayer = tintedTemplateImage(template, color: .white)
        let blackLayer = tintedTemplateImage(template, color: .black)
        return compositeOutlinedDog(whiteLayer: whiteLayer, blackLayer: blackLayer, pixelSize: pixelSize)
    }

    private static func compositeSystemDogFill(pixelSize: CGFloat) -> NSImage {
        let pt = pixelSize * 0.42
        let cfg = NSImage.SymbolConfiguration(pointSize: pt, weight: .regular)
        guard let raw = NSImage(systemSymbolName: "dog.fill", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else {
            return NSImage(size: NSSize(width: pixelSize, height: pixelSize))
        }
        let whiteLayer = tintedTemplateImage(raw, color: .white)
        let blackLayer = tintedTemplateImage(raw, color: .black)
        return compositeOutlinedDog(whiteLayer: whiteLayer, blackLayer: blackLayer, pixelSize: pixelSize)
    }

    /// 模板图着色（与 `NSImageView` + `contentTintColor` 效果一致，供离屏合成）。
    private static func tintedTemplateImage(_ image: NSImage, color: NSColor) -> NSImage {
        let sz = image.size
        guard sz.width > 1, sz.height > 1 else { return image }
        let from = NSRect(origin: .zero, size: sz)
        return NSImage(size: sz, flipped: false) { rect in
            color.setFill()
            rect.fill()
            image.draw(in: rect, from: from, operation: .destinationIn, fraction: 1, respectFlipped: true, hints: nil)
            return true
        }
    }

    /// 外层（白）边长 = 内层（黑）× `outlineScale`，与 `PetRenderer.layoutPet` 一致。
    private static func compositeOutlinedDog(
        whiteLayer: NSImage,
        blackLayer: NSImage,
        pixelSize: CGFloat
    ) -> NSImage {
        let inner = pixelSize * 0.58
        let outer = inner * outlineScale
        return NSImage(size: NSSize(width: pixelSize, height: pixelSize), flipped: false) { bounds in
            let ox = (bounds.width - outer) / 2
            let oy = (bounds.height - outer) / 2
            whiteLayer.draw(
                in: NSRect(x: ox, y: oy, width: outer, height: outer),
                from: NSRect(origin: .zero, size: whiteLayer.size),
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
            let ix = (bounds.width - inner) / 2
            let iy = (bounds.height - inner) / 2
            blackLayer.draw(
                in: NSRect(x: ix, y: iy, width: inner, height: inner),
                from: NSRect(origin: .zero, size: blackLayer.size),
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
            return true
        }
    }
}
