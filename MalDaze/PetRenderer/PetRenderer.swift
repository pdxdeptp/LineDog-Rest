import AppKit

@MainActor
protocol PetRendering: AnyObject {
    func install(in parent: NSView)
    func layoutPet(in bounds: CGRect, visualCenter: CGPoint, scale: CGFloat)
    func setDisplayMode(_ mode: PetDisplayMode)
}

@MainActor
final class PetRenderer: PetRendering {
    private let imageView = NSImageView()

    // Resolved once at init; empty array means fall back to SF Symbol.
    private let gifURLsByMode: [PetDisplayMode: [URL]]

    // Variant cycling for continuous states (idle / thinking).
    private var cycleTimer: Timer?
    private var activeURLs: [URL] = []
    private var activeIndex: Int = 0
    private static let variantRotationInterval: TimeInterval = 5 * 60

    init() {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        imageView.wantsLayer = true
        gifURLsByMode = Self.resolveGIFURLs()
    }

    private static func resolveGIFURLs() -> [PetDisplayMode: [URL]] {
        func gif(_ folder: String, _ name: String) -> URL? {
            Bundle.main.url(forResource: name, withExtension: "gif", subdirectory: "LineDog/\(folder)")
        }
        return [
            .runningBlack: [
                gif("idle", "线条小狗第12弹_无聊"),
                gif("idle", "线条小狗第12弹_晃脚脚"),
                gif("idle", "线条小狗第1弹_摆烂"),
                gif("idle", "线条小狗第9弹_甩耳朵"),
            ].compactMap { $0 },
            .restingRed: [
                gif("breakPrompt", "线条小狗第2弹_激动"),
                gif("breakPrompt", "线条小狗第5弹_偷看"),
                gif("breakPrompt", "线条小狗第5弹_出去玩"),
                gif("breakRunning", "线条小狗第1弹_啦啦啦"),
                gif("breakRunning", "线条小狗第1弹_来了"),
            ].compactMap { $0 },
            .pausedWhiteOutline: [
                gif("sleeping", "线条小狗第12弹_困"),
            ].compactMap { $0 },
            .thinking: [
                gif("focusGuard", "线条小狗第17弹_工作"),
                gif("focusGuard", "线条小狗第2弹_努力"),
                gif("focusGuard", "线条小狗第9弹_甩耳朵"),
            ].compactMap { $0 },
        ]
    }

    func install(in parent: NSView) {
        imageView.translatesAutoresizingMaskIntoConstraints = true
        parent.addSubview(imageView)
        setDisplayMode(.runningBlack)
    }

    func setDisplayMode(_ mode: PetDisplayMode) {
        let urls = gifURLsByMode[mode] ?? []
        startGIFCycle(urls: urls, continuous: mode == .runningBlack || mode == .thinking)
    }

    private func startGIFCycle(urls: [URL], continuous: Bool) {
        cycleTimer?.invalidate()
        cycleTimer = nil
        activeURLs = urls
        guard !urls.isEmpty else {
            applyFallbackSymbol()
            return
        }
        activeIndex = Int.random(in: 0..<urls.count)
        loadGIF(url: urls[activeIndex])
        guard continuous, urls.count > 1 else { return }
        let t = Timer.scheduledTimer(withTimeInterval: Self.variantRotationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.rotateVariant() }
        }
        RunLoop.main.add(t, forMode: .common)
        cycleTimer = t
    }

    private func rotateVariant() {
        guard activeURLs.count > 1 else { return }
        let prev = activeIndex
        var next = Int.random(in: 0..<activeURLs.count)
        if next == prev { next = (next + 1) % activeURLs.count }
        activeIndex = next
        loadGIF(url: activeURLs[next])
    }

    private func loadGIF(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let image = NSImage(data: data) else {
            applyFallbackSymbol()
            return
        }
        imageView.image = image
        imageView.animates = true
    }

    private func applyFallbackSymbol() {
        let cfg = NSImage.SymbolConfiguration(pointSize: 128, weight: .regular)
        let sym = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "pet")?
            .withSymbolConfiguration(cfg)
        imageView.image = sym
    }

    func layoutPet(in bounds: CGRect, visualCenter: CGPoint, scale: CGFloat) {
        let base = min(bounds.width, bounds.height) * 0.22
        let side = base * scale
        imageView.frame = CGRect(
            x: visualCenter.x - side / 2,
            y: visualCenter.y - side / 2,
            width: side,
            height: side
        )
    }

    nonisolated func invalidateCycleTimer() {
        // Called from deinit; timer is captured weakly so this is safe cross-actor.
    }

    deinit {
        // cycleTimer.invalidate() requires main actor; schedule it safely.
        let t = cycleTimer
        DispatchQueue.main.async { t?.invalidate() }
    }
}
