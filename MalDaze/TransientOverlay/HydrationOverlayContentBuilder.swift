import AppKit
import ObjectiveC
import QuartzCore

private final class HydrationReminderCardView: NSView {
    private let gradientLayer = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        guard let layer else { return }
        layer.cornerRadius = 18
        if #available(macOS 11.0, *) {
            layer.cornerCurve = .continuous
        }
        layer.borderWidth = 1
        layer.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = NSSize(width: 0, height: -4)
        layer.shadowRadius = 14

        gradientLayer.colors = [
            NSColor.systemBlue.withAlphaComponent(0.14).cgColor,
            NSColor.controlBackgroundColor.withAlphaComponent(0.97).cgColor,
        ]
        gradientLayer.locations = [0, 1] as [NSNumber]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.28)
        gradientLayer.cornerRadius = 18
        gradientLayer.masksToBounds = true
        layer.insertSublayer(gradientLayer, at: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
    }
}

enum HydrationOverlayContentBuilder {
    private static let reminderMaxTextWidth: CGFloat = 360
    private static let reminderPadding: CGFloat = 22
    private static let reminderIconGap: CGFloat = 14
    private static let reminderIconSide: CGFloat = 64
    private static let buttonH: CGFloat = 48
    private static let buttonGap: CGFloat = 12
    private static let reminderMessageFontSize: CGFloat = 17
    private static let reminderButtonFontSize: CGFloat = 15
    private static let reminderIconSymbolPointSize: CGFloat = 40

    private static func snoozeButtonBackgroundColor() -> NSColor {
        if #available(macOS 14.0, *) {
            return .quaternarySystemFill
        }
        return NSColor(name: nil) { appearance in
            let dark =
                appearance.name == .darkAqua
                || appearance.name == .vibrantDark
                || appearance.name == .accessibilityHighContrastDarkAqua
            if dark {
                return NSColor.white.withAlphaComponent(0.14)
            }
            return NSColor.black.withAlphaComponent(0.07)
        }
    }

    static func contentSize(for message: String) -> NSSize {
        let pad = reminderPadding
        let maxInnerW = reminderMaxTextWidth - 2 * pad
        let font = NSFont.systemFont(ofSize: reminderMessageFontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let rect = (message as NSString).boundingRect(
            with: NSSize(width: max(80, maxInnerW), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        let textH = ceil(max(24, rect.height))
        let w = max(300, min(reminderMaxTextWidth, ceil(rect.width) + 2 * pad))
        let buttonsH = buttonH * 2 + buttonGap
        let h = pad + reminderIconSide + reminderIconGap + textH + reminderIconGap + buttonsH + pad
        return NSSize(width: w, height: h)
    }

    static func makeContentView(
        message: String,
        onDone: @escaping () -> Void,
        onSnooze: @escaping () -> Void
    ) -> (view: NSView, size: NSSize) {
        let size = contentSize(for: message)
        let container = HydrationReminderCardView(frame: NSRect(origin: .zero, size: size))

        let baseSymbol =
            NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "喝水")
            ?? NSImage(size: NSSize(width: 48, height: 48))
        let cfg = NSImage.SymbolConfiguration(pointSize: reminderIconSymbolPointSize, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.systemBlue]))
        let iconImg = baseSymbol.withSymbolConfiguration(cfg) ?? baseSymbol
        let imgView = NSImageView(image: iconImg)
        imgView.imageScaling = .scaleProportionallyUpOrDown
        imgView.imageAlignment = .alignCenter
        imgView.isEditable = false

        let textField = NSTextField(wrappingLabelWithString: message)
        textField.font = NSFont.systemFont(ofSize: reminderMessageFontSize, weight: .semibold)
        textField.textColor = .labelColor
        textField.alignment = .center
        textField.maximumNumberOfLines = 0
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBordered = false
        textField.drawsBackground = false

        let buttonFont = NSFont.systemFont(ofSize: reminderButtonFontSize, weight: .semibold)
        let buttonFontSecondary = NSFont.systemFont(ofSize: reminderButtonFontSize, weight: .medium)

        let doneButton = NSButton(title: "", target: nil, action: nil)
        doneButton.bezelStyle = .rounded
        doneButton.isBordered = false
        doneButton.wantsLayer = true
        doneButton.layer?.cornerRadius = 12
        if #available(macOS 11.0, *) {
            doneButton.layer?.cornerCurve = .continuous
        }
        doneButton.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        doneButton.attributedTitle = NSAttributedString(
            string: "已喝水 💧",
            attributes: [
                .foregroundColor: NSColor.white,
                .font: buttonFont,
            ]
        )
        doneButton.keyEquivalent = "\r"

        let snoozeButton = NSButton(title: "", target: nil, action: nil)
        snoozeButton.bezelStyle = .rounded
        snoozeButton.isBordered = false
        snoozeButton.wantsLayer = true
        snoozeButton.layer?.cornerRadius = 12
        if #available(macOS 11.0, *) {
            snoozeButton.layer?.cornerCurve = .continuous
        }
        snoozeButton.layer?.backgroundColor = snoozeButtonBackgroundColor().cgColor
        snoozeButton.layer?.borderWidth = 1
        snoozeButton.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.65).cgColor
        snoozeButton.attributedTitle = NSAttributedString(
            string: "稍后提醒",
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: buttonFontSecondary,
            ]
        )

        let actionHandler = HydrationOverlayActionHandler(onDone: onDone, onSnooze: onSnooze)
        doneButton.target = actionHandler
        doneButton.action = #selector(HydrationOverlayActionHandler.doneTapped)
        snoozeButton.target = actionHandler
        snoozeButton.action = #selector(HydrationOverlayActionHandler.snoozeTapped)
        objc_setAssociatedObject(container, &HydrationOverlayActionHandler.associationKey, actionHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let pad = reminderPadding
        let iconY = size.height - pad - reminderIconSide
        imgView.frame = NSRect(
            x: (size.width - reminderIconSide) / 2,
            y: iconY,
            width: reminderIconSide,
            height: reminderIconSide
        )

        let snoozeY = pad
        let doneY = snoozeY + buttonH + buttonGap
        let textY = doneY + buttonH + reminderIconGap
        let textH = max(24, iconY - reminderIconGap - textY)

        let btnW = size.width - 2 * pad
        snoozeButton.frame = NSRect(x: pad, y: snoozeY, width: btnW, height: buttonH)
        doneButton.frame = NSRect(x: pad, y: doneY, width: btnW, height: buttonH)
        textField.frame = NSRect(x: pad, y: textY, width: btnW, height: textH)

        container.addSubview(imgView)
        container.addSubview(textField)
        container.addSubview(doneButton)
        container.addSubview(snoozeButton)

        return (container, size)
    }
}

private final class HydrationOverlayActionHandler: NSObject {
    static var associationKey: UInt8 = 0

    private let onDone: () -> Void
    private let onSnooze: () -> Void

    init(onDone: @escaping () -> Void, onSnooze: @escaping () -> Void) {
        self.onDone = onDone
        self.onSnooze = onSnooze
    }

    @objc func doneTapped() { onDone() }
    @objc func snoozeTapped() { onSnooze() }
}
