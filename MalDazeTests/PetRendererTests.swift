import AppKit
import ImageIO
import XCTest
@testable import MalDaze

@MainActor
final class PetRendererTests: XCTestCase {
    override func tearDown() {
        let ud = UserDefaults.standard
        ud.removeObject(forKey: MalDazeDefaults.idlePetAnimationIntensity)
        ud.removeObject(forKey: MalDazeDefaults.idlePetIconAnimationEnabled)
        super.tearDown()
    }

    func testMigration_legacyBoolFalse_mapsToZeroIntensity() {
        let ud = UserDefaults.standard
        ud.removeObject(forKey: MalDazeDefaults.idlePetAnimationIntensity)
        ud.set(false, forKey: MalDazeDefaults.idlePetIconAnimationEnabled)
        XCTAssertEqual(MalDazeDefaults.resolvedIdlePetAnimationIntensity(), 0, accuracy: 0.0001)
    }

    func testMigration_legacyBoolTrue_mapsToOneIntensity() {
        let ud = UserDefaults.standard
        ud.removeObject(forKey: MalDazeDefaults.idlePetAnimationIntensity)
        ud.set(true, forKey: MalDazeDefaults.idlePetIconAnimationEnabled)
        XCTAssertEqual(MalDazeDefaults.resolvedIdlePetAnimationIntensity(), 1, accuracy: 0.0001)
    }

    func testResolvedIntensity_whenNewKeyPresent_noLegacyRead() {
        let ud = UserDefaults.standard
        ud.set(0.42, forKey: MalDazeDefaults.idlePetAnimationIntensity)
        ud.set(true, forKey: MalDazeDefaults.idlePetIconAnimationEnabled)
        XCTAssertEqual(MalDazeDefaults.resolvedIdlePetAnimationIntensity(), 0.42, accuracy: 0.0001)
    }

    func testSetAnimationIntensityZero_animatesFalseWhenGIFLoads() {
        let pet = PetRenderer()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        pet.install(in: container)
        pet.setAnimationIntensity(0)
        XCTAssertFalse(pet.testing_imageViewAnimates)

        pet.setAnimationIntensity(1)
        let gifSample = Bundle.main.url(
            forResource: "线条小狗第12弹_无聊",
            withExtension: "gif",
            subdirectory: "LineDog/idle"
        )
        if gifSample != nil {
            XCTAssertTrue(pet.testing_imageViewAnimates)
        } else {
            XCTAssertFalse(pet.testing_imageViewAnimates)
        }
    }

    func testAnimationIntensityZero_noVariantRotationTimerInRunningBlack() {
        let pet = PetRenderer()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        pet.install(in: container)
        pet.setAnimationIntensity(0)
        XCTAssertFalse(pet.testing_variantCycleTimerExists)
    }

    func testBreakRunningDisplayModeUsesDedicatedBreakRunningAssetsWithoutVariantRotation() throws {
        let pet = PetRenderer()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        pet.install(in: container)
        pet.setAnimationIntensity(1)

        pet.setDisplayMode(.breakRunning)

        XCTAssertEqual(pet.testing_currentMode, .breakRunning)
        XCTAssertFalse(pet.testing_variantCycleTimerExists)
        let activeURLs = pet.testing_activeURLs
        XCTAssertEqual(
            activeURLs.map(\.lastPathComponent).sorted(),
            [
                "线条小狗第1弹_啦啦啦.gif",
                "线条小狗第1弹_来了.gif",
            ].sorted()
        )
        XCTAssertTrue(activeURLs.allSatisfy { $0.path.contains("/LineDog/breakRunning/") })
    }

    func testBreakRunningDisplayModeUsesFullMotionPlaybackRegardlessOfIdleIntensity() throws {
        try Self.requireBreakRunningGIF()
        for intensity in [0.0, 0.5] {
            let pet = PetRenderer()
            let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
            pet.install(in: container)
            pet.setAnimationIntensity(intensity)

            pet.setDisplayMode(.breakRunning)

            XCTAssertEqual(pet.testing_currentMode, .breakRunning)
            XCTAssertTrue(pet.testing_imageViewAnimates, "Expected breakRunning to use native full-motion playback at intensity \(intensity).")
            XCTAssertFalse(pet.testing_manualPlaybackTimerExists, "Expected breakRunning to skip manual slow-frame playback at intensity \(intensity).")
            XCTAssertFalse(pet.testing_variantCycleTimerExists)
        }
    }

    func testFullMotionSameDisplayModeDoesNotReloadImage() throws {
        try Self.requirePausedWhiteOutlineGIF()
        let pet = PetRenderer()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        pet.install(in: container)
        pet.setAnimationIntensity(1)

        pet.setDisplayMode(.pausedWhiteOutline)
        let firstImage = try Self.currentImage(from: pet)

        pet.setDisplayMode(.pausedWhiteOutline)
        let secondImage = try Self.currentImage(from: pet)

        XCTAssertTrue(firstImage === secondImage)
        XCTAssertTrue(pet.testing_imageViewAnimates)
        XCTAssertFalse(pet.testing_variantCycleTimerExists)
    }

    func testBreakRunDisplayRestoresPreviousNonRestModeWhenCancelled() throws {
        let stage = PetStageView(frame: NSRect(x: 0, y: 0, width: 240, height: 240))
        stage.applyNonRestPetDisplayMode(.pausedWhiteOutline)

        stage.beginBreakRunDisplay(total: 60)

        XCTAssertEqual(stage.testing_petDisplayMode, .breakRunning)

        stage.cancelBreakRunToIdle()

        XCTAssertEqual(stage.testing_petDisplayMode, .pausedWhiteOutline)
    }

    func testBreakRunDisplayKeepsBreakRunningModeAfterLayout() throws {
        let stage = PetStageView(frame: NSRect(x: 0, y: 0, width: 240, height: 240))
        stage.applyNonRestPetDisplayMode(.pausedWhiteOutline)
        stage.beginBreakRunDisplay(total: 60)

        stage.layout()

        XCTAssertEqual(stage.testing_petDisplayMode, .breakRunning)
    }

    func testIntermediateIntensity_startsManualPlaybackWhenGifPresent() {
        let gifSample = Bundle.main.url(
            forResource: "线条小狗第12弹_无聊",
            withExtension: "gif",
            subdirectory: "LineDog/idle"
        )
        guard gifSample != nil else {
            return
        }
        let pet = PetRenderer()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        pet.install(in: container)
        pet.setAnimationIntensity(0.5)
        XCTAssertTrue(pet.testing_manualPlaybackTimerExists)
        XCTAssertFalse(pet.testing_imageViewAnimates)
    }

    func testStaticFirstFrame_reusesDecodedFrameForSameGIFURL() throws {
        try Self.requirePausedWhiteOutlineGIF()
        let pet = PetRenderer()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        pet.install(in: container)
        pet.setAnimationIntensity(0)

        pet.setDisplayMode(.pausedWhiteOutline)
        let firstImage = try Self.currentImage(from: pet)
        pet.setDisplayMode(.pausedWhiteOutline)
        let secondImage = try Self.currentImage(from: pet)

        XCTAssertTrue(firstImage === secondImage)
        XCTAssertFalse(pet.testing_imageViewAnimates)
    }

    func testIntermediatePlayback_reusesDecodedFramesAndReschedulesWithCurrentIntensityForSameGIFURL() throws {
        try Self.requirePausedWhiteOutlineGIF()
        let pet = PetRenderer()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        pet.install(in: container)

        pet.setAnimationIntensity(0.25)
        pet.setDisplayMode(.pausedWhiteOutline)
        let firstImage = try Self.currentImage(from: pet)
        let firstDelay = try Self.manualPlaybackTimer(from: pet).fireDate.timeIntervalSinceNow

        pet.setAnimationIntensity(0.5)
        let secondImage = try Self.currentImage(from: pet)
        let secondDelay = try Self.manualPlaybackTimer(from: pet).fireDate.timeIntervalSinceNow

        XCTAssertTrue(firstImage === secondImage)
        XCTAssertLessThan(secondDelay, firstDelay * 0.75)
        XCTAssertFalse(pet.testing_imageViewAnimates)
    }

    private static func requireBreakRunningGIF() throws {
        guard let url = Bundle.main.url(
            forResource: "线条小狗第1弹_啦啦啦",
            withExtension: "gif",
            subdirectory: "LineDog/breakRunning"
        ) else {
            throw XCTSkip("Break-running GIF fixture is not bundled in this test run.")
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 1 else {
            throw XCTSkip("Break-running GIF fixture is not decodable as a multi-frame GIF.")
        }
    }

    private static func requirePausedWhiteOutlineGIF() throws {
        guard let url = Bundle.main.url(
            forResource: "线条小狗第12弹_困",
            withExtension: "gif",
            subdirectory: "LineDog/sleeping"
        ) else {
            throw XCTSkip("Paused white outline GIF fixture is not bundled in this test run.")
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 1 else {
            throw XCTSkip("Paused white outline GIF fixture is not decodable as a multi-frame GIF.")
        }
    }

    private static func currentImage(from pet: PetRenderer, file: StaticString = #filePath, line: UInt = #line) throws -> NSImage {
        guard let imageView = mirroredValue(named: "imageView", from: pet) as? NSImageView else {
            XCTFail("Could not inspect PetRenderer imageView.", file: file, line: line)
            throw TestAccessError.missingMirrorValue("imageView")
        }
        guard let image = imageView.image else {
            XCTFail("Expected PetRenderer to display an image.", file: file, line: line)
            throw TestAccessError.missingMirrorValue("image")
        }
        return image
    }

    private static func manualPlaybackTimer(from pet: PetRenderer, file: StaticString = #filePath, line: UInt = #line) throws -> Timer {
        if let timer = mirroredValue(named: "manualPlaybackTimer", from: pet) as? Timer {
            return timer
        }
        XCTFail("Expected intermediate GIF playback to schedule a timer.", file: file, line: line)
        throw TestAccessError.missingMirrorValue("manualPlaybackTimer")
    }

    private static func mirroredValue(named name: String, from pet: PetRenderer) -> Any? {
        var mirror: Mirror? = Mirror(reflecting: pet)
        while let current = mirror {
            if let value = current.children.first(where: { $0.label == name })?.value {
                return value
            }
            mirror = current.superclassMirror
        }
        return nil
    }

    private enum TestAccessError: Error {
        case missingMirrorValue(String)
    }
}
