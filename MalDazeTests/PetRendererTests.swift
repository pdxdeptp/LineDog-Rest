import AppKit
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

    func testBreakRunningDisplayModeUsesDedicatedBreakRunningAssetsWithoutVariantRotation() {
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

    func testBreakRunDisplayRestoresPreviousNonRestModeWhenCancelled() {
        let stage = PetStageView(frame: NSRect(x: 0, y: 0, width: 240, height: 240))
        stage.applyNonRestPetDisplayMode(.pausedWhiteOutline)

        stage.beginBreakRunDisplay(total: 60)

        XCTAssertEqual(stage.testing_petDisplayMode, .breakRunning)

        stage.cancelBreakRunToIdle()

        XCTAssertEqual(stage.testing_petDisplayMode, .pausedWhiteOutline)
    }

    func testBreakRunDisplayKeepsBreakRunningModeAfterLayout() {
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

}
