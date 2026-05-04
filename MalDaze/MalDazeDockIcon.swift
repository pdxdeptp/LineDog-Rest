import AppKit

/// Dock / NSApplication.applicationIconImage 用图：pawprint.fill SF Symbol 白边叠黑身。
enum MalDazeDockIcon {
    private static let outlineScale: CGFloat = 1.14

    static func makeImage(pixelSize: CGFloat = 512) -> NSImage {
        let pt = pixelSize * 0.52
        let cfg = NSImage.SymbolConfiguration(pointSize: pt, weight: .regular)
        guard let raw = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(cfg) else {
            return NSImage(size: NSSize(width: pixelSize, height: pixelSize))
        }
        let whiteLayer = tintedTemplateImage(raw, color: .white)
        let blackLayer = tintedTemplateImage(raw, color: .black)
        return compositeOutlined(whiteLayer: whiteLayer, blackLayer: blackLayer, pixelSize: pixelSize)
    }

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

    private static func compositeOutlined(whiteLayer: NSImage, blackLayer: NSImage, pixelSize: CGFloat) -> NSImage {
        let inner = pixelSize * 0.58
        let outer = inner * outlineScale
        return NSImage(size: NSSize(width: pixelSize, height: pixelSize), flipped: false) { bounds in
            let ox = (bounds.width - outer) / 2
            let oy = (bounds.height - outer) / 2
            whiteLayer.draw(
                in: NSRect(x: ox, y: oy, width: outer, height: outer),
                from: NSRect(origin: .zero, size: whiteLayer.size),
                operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil
            )
            let ix = (bounds.width - inner) / 2
            let iy = (bounds.height - inner) / 2
            blackLayer.draw(
                in: NSRect(x: ix, y: iy, width: inner, height: inner),
                from: NSRect(origin: .zero, size: blackLayer.size),
                operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil
            )
            return true
        }
    }
}
