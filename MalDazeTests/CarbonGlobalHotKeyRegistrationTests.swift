import AppKit
import Carbon.HIToolbox
import XCTest
@testable import MalDaze

final class CarbonGlobalHotKeyRegistrationTests: XCTestCase {
    func testRegistrationSlotsKeepExistingCarbonIDsSignatureAndNotificationNames() {
        let descriptors = MalDazeCarbonGlobalHotKeys.registrationSlotDescriptors

        XCTAssertEqual(descriptors.map(\.id), [1, 2, 3, 4])
        XCTAssertTrue(descriptors.allSatisfy { $0.signature == 0x4C44_4F47 })
        XCTAssertEqual(
            descriptors.map(\.notificationName),
            [
                MalDazeBroadcastNotifications.presentDeskPetMenu,
                MalDazeBroadcastNotifications.openSmartReminderInput,
                MalDazeBroadcastNotifications.toggleSevenMinuteReminder,
                MalDazeBroadcastNotifications.resetIdlePetPositionToDefault
            ]
        )
    }

    func testDisabledShortcutPlansNoRegistrationAndClearsInstalledRef() {
        let slot = makeSlot(id: 1)
        let installed = CarbonHotKeyShortcut(keyCode: 47, modifiers: [.command, .shift])
        let disabled = CarbonHotKeyShortcut(keyCode: 47, modifiers: [])
        let state = CarbonHotKeyRegistrationState(installedShortcut: installed, hasHotKeyRef: true)

        let plan = slot.plan(for: disabled, state: state)

        XCTAssertTrue(plan.shouldUnregister)
        XCTAssertNil(plan.registrationRequest)
        XCTAssertEqual(
            plan.stateWithoutRegistration,
            CarbonHotKeyRegistrationState(installedShortcut: disabled, hasHotKeyRef: false)
        )
    }

    func testUnchangedEnabledShortcutRetainsExistingRegistration() {
        let slot = makeSlot(id: 2)
        let shortcut = CarbonHotKeyShortcut(keyCode: 43, modifiers: [.command, .shift])
        let state = CarbonHotKeyRegistrationState(installedShortcut: shortcut, hasHotKeyRef: true)

        let plan = slot.plan(for: shortcut, state: state)

        XCTAssertFalse(plan.shouldUnregister)
        XCTAssertNil(plan.registrationRequest)
        XCTAssertEqual(plan.stateWithoutRegistration, state)
    }

    func testMissingRefForSameEnabledShortcutRegistersAgain() {
        let slot = makeSlot(id: 3)
        let shortcut = CarbonHotKeyShortcut(keyCode: 46, modifiers: [.command, .shift])
        let state = CarbonHotKeyRegistrationState(installedShortcut: shortcut, hasHotKeyRef: false)

        let plan = slot.plan(for: shortcut, state: state)

        XCTAssertFalse(plan.shouldUnregister)
        XCTAssertEqual(
            plan.registrationRequest,
            CarbonHotKeyRegistrationRequest(
                hotKeyID: EventHotKeyID(signature: 0x4C44_4F47, id: 3),
                keyCode: 46,
                modifiers: [.command, .shift]
            )
        )
        XCTAssertEqual(
            plan.stateAfterRegistration(succeeded: true),
            CarbonHotKeyRegistrationState(installedShortcut: shortcut, hasHotKeyRef: true)
        )
        XCTAssertEqual(
            plan.stateAfterRegistration(succeeded: false),
            CarbonHotKeyRegistrationState(installedShortcut: nil, hasHotKeyRef: false)
        )
    }

    func testChangedEnabledShortcutUnregistersBeforeRegisteringReplacement() {
        let slot = makeSlot(id: 4)
        let installed = CarbonHotKeyShortcut(keyCode: 15, modifiers: [.command, .shift])
        let replacement = CarbonHotKeyShortcut(keyCode: 36, modifiers: [.control, .option])
        let state = CarbonHotKeyRegistrationState(installedShortcut: installed, hasHotKeyRef: true)

        let plan = slot.plan(for: replacement, state: state)

        XCTAssertTrue(plan.shouldUnregister)
        XCTAssertEqual(
            plan.registrationRequest,
            CarbonHotKeyRegistrationRequest(
                hotKeyID: EventHotKeyID(signature: 0x4C44_4F47, id: 4),
                keyCode: 36,
                modifiers: [.control, .option]
            )
        )
        XCTAssertEqual(
            plan.stateAfterRegistration(succeeded: true),
            CarbonHotKeyRegistrationState(installedShortcut: replacement, hasHotKeyRef: true)
        )
        XCTAssertEqual(
            plan.stateAfterRegistration(succeeded: false),
            CarbonHotKeyRegistrationState(installedShortcut: nil, hasHotKeyRef: false)
        )
    }

    private func makeSlot(id: UInt32) -> CarbonHotKeyRegistrationSlot {
        CarbonHotKeyRegistrationSlot(
            id: id,
            notificationName: Notification.Name("test.\(id)"),
            loadShortcut: { CarbonHotKeyShortcut(keyCode: 0, modifiers: []) }
        )
    }
}
