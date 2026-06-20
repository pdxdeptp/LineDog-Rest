import AppKit

enum CenterBellOverlayContentBuilder {
    private static let reminderMaxTextWidth: CGFloat = 280
    private static let reminderPadding: CGFloat = 20
    private static let reminderIconGap: CGFloat = 12
    private static let reminderIconSide: CGFloat = 52

    static func contentSize(for message: String) -> NSSize {
        let pad = reminderPadding
        let maxInnerW = reminderMaxTextWidth - 2 * pad
        let font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let rect = (message as NSString).boundingRect(
            with: NSSize(width: max(80, maxInnerW), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        let textH = ceil(max(24, rect.height))
        let w = max(200, min(reminderMaxTextWidth, ceil(rect.width) + 2 * pad))
        let h = pad + reminderIconSide + reminderIconGap + textH + pad
        return NSSize(width: w, height: h)
    }

    static func makeContentView(message: String, onDismiss: @escaping () -> Void) -> (view: NSView, size: NSSize) {
        let size = contentSize(for: message)
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.94).cgColor
        container.layer?.cornerRadius = 16
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        container.layer?.shadowColor = NSColor.black.cgColor
        container.layer?.shadowOpacity = 0.22
        container.layer?.shadowOffset = NSSize(width: 0, height: -3)
        container.layer?.shadowRadius = 12

        let baseSymbol =
            NSImage(systemSymbolName: "bell.badge.fill", accessibilityDescription: "提醒")
            ?? NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "提醒")
            ?? NSImage(size: NSSize(width: 48, height: 48))
        let cfg = NSImage.SymbolConfiguration(pointSize: 36, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.systemOrange]))
        let iconImg = baseSymbol.withSymbolConfiguration(cfg) ?? baseSymbol
        let imgView = NSImageView(image: iconImg)
        imgView.imageScaling = .scaleProportionallyUpOrDown
        imgView.imageAlignment = .alignCenter
        imgView.isEditable = false

        let textField = NSTextField(wrappingLabelWithString: message)
        textField.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        textField.textColor = .labelColor
        textField.alignment = .center
        textField.maximumNumberOfLines = 0
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBordered = false
        textField.drawsBackground = false

        let pad = reminderPadding
        let iconY = size.height - pad - reminderIconSide
        imgView.frame = NSRect(
            x: (size.width - reminderIconSide) / 2,
            y: iconY,
            width: reminderIconSide,
            height: reminderIconSide
        )
        let textY = pad
        let textH = iconY - reminderIconGap - textY
        textField.frame = NSRect(x: pad, y: textY, width: size.width - 2 * pad, height: max(24, textH))

        let overlay = CenterBellDismissPanelView(frame: container.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.clear.cgColor
        overlay.onDismiss = onDismiss

        container.addSubview(imgView)
        container.addSubview(textField)
        container.addSubview(overlay)

        return (container, size)
    }
}

private final class CenterBellDismissPanelView: NSView {
    var onDismiss: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onDismiss?()
    }
}
