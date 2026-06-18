import AppKit
import ImageIO

@MainActor
protocol PetRendering: AnyObject {
    func install(in parent: NSView)
    func layoutPet(in bounds: CGRect, visualCenter: CGPoint, scale: CGFloat)
    func setDisplayMode(_ mode: PetDisplayMode)
    func setAnimationIntensity(_ intensity: Double)
}

@MainActor
final class PetRenderer: PetRendering {
    private let imageView = NSImageView()

    private let gifURLsByMode: [PetDisplayMode: [URL]]

    private var cycleTimer: Timer?
    private var activeURLs: [URL] = []
    private var activeIndex: Int = 0
    private static let variantRotationInterval: TimeInterval = 5 * 60

    private var currentMode: PetDisplayMode = .runningBlack
    private var animationIntensity: Double

    private var manualPlaybackFrames: [(NSImage, TimeInterval)] = []
    private var manualPlaybackTimer: Timer?
    private var manualPlaybackIndex: Int = 0

    private static let intensityFullNativeThreshold = 0.999
    private static let intensityStaticThreshold = 0.001
    /// 中间强度统一降帧播放，避免每帧 one-shot Timer。
    private static let intermediateTargetFPS: Double = 12

    private enum PlaybackMode: Equatable {
        case staticFirstFrame
        case intermediate(Double)
        case nativeAnimated
    }

    private struct RenderStateKey: Equatable {
        let mode: PetDisplayMode
        let urls: [URL]
        let playbackMode: PlaybackMode
        let allowsVariantRotationWhenAnimated: Bool
    }

    private var renderedStateKey: RenderStateKey?

    init() {
        animationIntensity = MalDazeDefaults.resolvedIdlePetAnimationIntensity()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = animationIntensity >= Self.intensityFullNativeThreshold
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
            ].compactMap { $0 },
            .breakRunning: [
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

    func setAnimationIntensity(_ intensity: Double) {
        animationIntensity = Self.clampedIntensity(intensity)
        setDisplayMode(currentMode)
    }

    func setDisplayMode(_ mode: PetDisplayMode) {
        currentMode = mode
        let urls = gifURLsByMode[mode] ?? []
        let allowsVariantRotation = mode == .runningBlack || mode == .thinking
        let effectiveIntensity = mode == .breakRunning ? 1 : animationIntensity
        let key = RenderStateKey(
            mode: mode,
            urls: urls,
            playbackMode: Self.playbackMode(for: effectiveIntensity),
            allowsVariantRotationWhenAnimated: allowsVariantRotation
        )
        if renderedStateKey == key, imageView.image != nil {
            return
        }
        renderedStateKey = key
        startGIFCycle(
            urls: urls,
            effectiveIntensity: effectiveIntensity,
            allowsVariantRotationWhenAnimated: allowsVariantRotation
        )
    }

    private static func playbackMode(for intensity: Double) -> PlaybackMode {
        let s = clampedIntensity(intensity)
        if s <= intensityStaticThreshold { return .staticFirstFrame }
        if s >= intensityFullNativeThreshold { return .nativeAnimated }
        return .intermediate(s)
    }

    private func startGIFCycle(urls: [URL], effectiveIntensity: Double, allowsVariantRotationWhenAnimated: Bool) {
        stopManualPlayback()
        cycleTimer?.invalidate()
        cycleTimer = nil
        activeURLs = urls
        guard !urls.isEmpty else {
            applyFallbackSymbol()
            return
        }
        activeIndex = Int.random(in: 0..<urls.count)
        let url = urls[activeIndex]

        let s = Self.clampedIntensity(effectiveIntensity)
        if s <= Self.intensityStaticThreshold {
            showStaticFirstFrame(url: url)
            return
        }
        if s >= Self.intensityFullNativeThreshold {
            loadGIF(url: url, nativeAnimated: true)
            let shouldRotate = allowsVariantRotationWhenAnimated && urls.count > 1
            guard shouldRotate else { return }
            let t = Timer.scheduledTimer(withTimeInterval: Self.variantRotationInterval, repeats: true) { [weak self] _ in
                self?.rotateVariant()
            }
            RunLoop.main.add(t, forMode: .common)
            cycleTimer = t
            return
        }

        beginIntermediateGIFPlayback(url: url, intensity: s)
    }

    private func rotateVariant() {
        guard animationIntensity >= Self.intensityFullNativeThreshold else { return }
        guard activeURLs.count > 1 else { return }
        let prev = activeIndex
        var next = Int.random(in: 0..<activeURLs.count)
        if next == prev { next = (next + 1) % activeURLs.count }
        activeIndex = next
        loadGIF(url: activeURLs[next], nativeAnimated: true)
    }

    private func loadGIF(url: URL, nativeAnimated: Bool) {
        let data: Data
        if let cached = GIFFrameCache.gifData(for: url) {
            data = cached
        } else if let loaded = try? Data(contentsOf: url) {
            GIFFrameCache.storeGIFData(loaded, for: url)
            data = loaded
        } else {
            applyFallbackSymbol()
            return
        }
        guard let image = NSImage(data: data) else {
            applyFallbackSymbol()
            return
        }
        imageView.image = image
        imageView.animates = nativeAnimated
    }

    private func showStaticFirstFrame(url: URL) {
        stopManualPlayback()
        if let frames = Self.cachedGIFFrames(url: url), let first = frames.first?.0 {
            imageView.image = first
            imageView.animates = false
            return
        }
        loadGIF(url: url, nativeAnimated: false)
    }

    private func beginIntermediateGIFPlayback(url: URL, intensity: Double) {
        stopManualPlayback()
        guard let frames = Self.cachedGIFFrames(url: url), frames.count >= 1 else {
            loadGIF(url: url, nativeAnimated: false)
            return
        }
        manualPlaybackFrames = frames
        manualPlaybackIndex = 0
        imageView.image = frames[0].0
        imageView.animates = false
        startIntermediatePlaybackTimer(intensity: Self.clampedIntensity(intensity))
    }

    private func startIntermediatePlaybackTimer(intensity: Double) {
        manualPlaybackTimer?.invalidate()
        manualPlaybackTimer = nil
        guard manualPlaybackFrames.count > 1 else { return }
        let speed = max(intensity, 0.05)
        let interval = 1.0 / (Self.intermediateTargetFPS * speed)
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advanceManualFrame()
        }
        RunLoop.main.add(t, forMode: .common)
        manualPlaybackTimer = t
    }

    private func advanceManualFrame() {
        guard !manualPlaybackFrames.isEmpty else { return }
        manualPlaybackIndex = (manualPlaybackIndex + 1) % manualPlaybackFrames.count
        imageView.image = manualPlaybackFrames[manualPlaybackIndex].0
        imageView.animates = false
    }

    private func stopManualPlayback() {
        manualPlaybackTimer?.invalidate()
        manualPlaybackTimer = nil
        manualPlaybackFrames = []
        manualPlaybackIndex = 0
    }

    private static func cachedGIFFrames(url: URL) -> [(NSImage, TimeInterval)]? {
        if let frames = GIFFrameCache.decodedFrames(for: url) { return frames }
        guard let frames = decodeGIFFrames(url: url) else { return nil }
        GIFFrameCache.storeDecodedFrames(frames, for: url)
        return frames
    }

    private static func decodeGIFFrames(url: URL) -> [(NSImage, TimeInterval)]? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let n = CGImageSourceGetCount(src)
        guard n > 0 else { return nil }
        var out: [(NSImage, TimeInterval)] = []
        out.reserveCapacity(n)
        for i in 0..<n {
            guard let cgImg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            let size = NSSize(width: cgImg.width, height: cgImg.height)
            let nsImg = NSImage(cgImage: cgImg, size: size)
            var delay = 0.1
            if let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [String: Any],
               let gif = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                if let u = gif[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double, u > 0 {
                    delay = u
                } else if let c = gif[kCGImagePropertyGIFDelayTime as String] as? Double, c > 0 {
                    delay = c
                }
            }
            out.append((nsImg, delay))
        }
        return out.isEmpty ? nil : out
    }

    private func applyFallbackSymbol() {
        stopManualPlayback()
        let cfg = NSImage.SymbolConfiguration(pointSize: 128, weight: .regular)
        let sym = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "pet")?
            .withSymbolConfiguration(cfg)
        imageView.image = sym
        imageView.animates = false
    }

    private static func clampedIntensity(_ x: Double) -> Double {
        min(max(x, 0), 1)
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

    deinit {
        let ct = cycleTimer
        let mt = manualPlaybackTimer
        DispatchQueue.main.async {
            ct?.invalidate()
            mt?.invalidate()
        }
    }

    // MARK: - Tests (@testable)

    internal var testing_currentMode: PetDisplayMode { currentMode }
    internal var testing_activeURLs: [URL] { activeURLs }
    internal var testing_imageViewAnimates: Bool { imageView.animates }
    internal var testing_variantCycleTimerExists: Bool { cycleTimer != nil }
    internal var testing_manualPlaybackTimerExists: Bool { manualPlaybackTimer != nil }
}
