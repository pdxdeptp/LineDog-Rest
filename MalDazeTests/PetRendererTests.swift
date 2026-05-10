import AppKit
import XCTest
@testable import MalDaze

@MainActor
final class PetRendererTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: MalDazeDefaults.idlePetIconAnimationEnabled)
        super.tearDown()
    }

    func testResolvedDefaults_animationKeyAbsent_defaultsToTrue() {
        UserDefaults.standard.removeObject(forKey: MalDazeDefaults.idlePetIconAnimationEnabled)
        XCTAssertTrue(MalDazeDefaults.resolvedIdlePetIconAnimationEnabled())
    }

    func testSetGIFAnimationDisabled_setsAnimatesFalseWhenImageLoads() {
        UserDefaults.standard.removeObject(forKey: MalDazeDefaults.idlePetIconAnimationEnabled)
        let pet = PetRenderer()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        pet.install(in: container)
        pet.setGIFAnimationEnabled(false)
        XCTAssertFalse(pet.testing_imageViewAnimates)

        pet.setGIFAnimationEnabled(true)
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

    func testAnimationDisabled_noVariantRotationTimerInRunningBlack() {
        UserDefaults.standard.removeObject(forKey: MalDazeDefaults.idlePetIconAnimationEnabled)
        let pet = PetRenderer()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        pet.install(in: container)
        pet.setGIFAnimationEnabled(false)
        XCTAssertFalse(pet.testing_variantCycleTimerExists)
    }
}
