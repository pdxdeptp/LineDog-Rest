import AppKit
import Carbon.HIToolbox

/// Carbon `RegisterEventHotKey`：桌宠菜单（id 1）、智能输入（id 2）、独立倒计时（id 3）、桌宠复位（id 4）。不依赖「辅助功能」。
enum MalDazeCarbonGlobalHotKeys {
    private static let signature: OSType = 0x4C44_4F47 // 'LDOG'
    private static let deskHotKeyID: UInt32 = 1
    private static let smartInputHotKeyID: UInt32 = 2
    private static let sevenMinuteHotKeyID: UInt32 = 3
    private static let resetIdlePetHotKeyID: UInt32 = 4

    private static var deskHotKeyRef: EventHotKeyRef?
    private static var smartInputHotKeyRef: EventHotKeyRef?
    private static var sevenMinuteHotKeyRef: EventHotKeyRef?
    private static var resetIdlePetHotKeyRef: EventHotKeyRef?
    private static var handlerRef: EventHandlerRef?
    private static var defaultsObserver: NSObjectProtocol?
    private static var lastDeskInstalled: DeskPetMenuShortcut?
    private static var lastSmartInstalled: SmartReminderInputShortcut?
    private static var lastSevenMinuteInstalled: SevenMinuteReminderShortcut?
    private static var lastResetIdlePetInstalled: ResetIdlePetPositionShortcut?

    static func start() {
        installHandlerIfNeeded()
        syncRegistration()
        guard defaultsObserver == nil else { return }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            syncRegistration()
        }
    }

    static func stop() {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
        defaultsObserver = nil
        unregisterDeskHotKey()
        unregisterSmartInputHotKey()
        unregisterSevenMinuteHotKey()
        unregisterResetIdlePetHotKey()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
        Self.handlerRef = nil
        lastDeskInstalled = nil
        lastSmartInstalled = nil
        lastSevenMinuteInstalled = nil
        lastResetIdlePetInstalled = nil
    }

    private static func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var ref: EventHandlerRef?
        typealias HandlerFn = @convention(c) (EventHandlerCallRef?, EventRef?, UnsafeMutableRawPointer?) -> OSStatus
        let upp: EventHandlerUPP = malDazeCarbonGlobalHotKeysCallback as HandlerFn
        let status = InstallEventHandler(GetApplicationEventTarget(), upp, 1, &spec, nil, &ref)
        if status == noErr {
            handlerRef = ref
        }
    }

    private static func unregisterDeskHotKey() {
        if let deskHotKeyRef {
            UnregisterEventHotKey(deskHotKeyRef)
        }
        deskHotKeyRef = nil
    }

    private static func unregisterSmartInputHotKey() {
        if let smartInputHotKeyRef {
            UnregisterEventHotKey(smartInputHotKeyRef)
        }
        smartInputHotKeyRef = nil
    }

    private static func unregisterSevenMinuteHotKey() {
        if let sevenMinuteHotKeyRef {
            UnregisterEventHotKey(sevenMinuteHotKeyRef)
        }
        sevenMinuteHotKeyRef = nil
    }

    private static func unregisterResetIdlePetHotKey() {
        if let resetIdlePetHotKeyRef {
            UnregisterEventHotKey(resetIdlePetHotKeyRef)
        }
        resetIdlePetHotKeyRef = nil
    }

    private static func syncRegistration() {
        installHandlerIfNeeded()
        guard handlerRef != nil else { return }

        let desk = DeskPetMenuShortcut.load()
        syncDeskHotKey(desk)

        let smart = SmartReminderInputShortcut.load()
        syncSmartInputHotKey(smart)

        let seven = SevenMinuteReminderShortcut.load()
        syncSevenMinuteHotKey(seven)

        let resetPet = ResetIdlePetPositionShortcut.load()
        syncResetIdlePetHotKey(resetPet)
    }

    private static func syncDeskHotKey(_ desk: DeskPetMenuShortcut) {
        guard desk.isEnabled else {
            unregisterDeskHotKey()
            lastDeskInstalled = desk
            return
        }
        if desk != lastDeskInstalled || deskHotKeyRef == nil {
            unregisterDeskHotKey()
            var ref: EventHotKeyRef?
            let hid = EventHotKeyID(signature: signature, id: deskHotKeyID)
            let status = RegisterEventHotKey(
                UInt32(desk.keyCode),
                malDazeCarbonModifierMask(for: desk.modifiers),
                hid,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr {
                deskHotKeyRef = ref
                lastDeskInstalled = desk
            } else {
                lastDeskInstalled = nil
            }
        }
    }

    private static func syncSmartInputHotKey(_ smart: SmartReminderInputShortcut) {
        guard smart.isEnabled else {
            unregisterSmartInputHotKey()
            lastSmartInstalled = smart
            return
        }
        if smart != lastSmartInstalled || smartInputHotKeyRef == nil {
            unregisterSmartInputHotKey()
            var ref: EventHotKeyRef?
            let hid = EventHotKeyID(signature: signature, id: smartInputHotKeyID)
            let status = RegisterEventHotKey(
                UInt32(smart.keyCode),
                malDazeCarbonModifierMask(for: smart.modifiers),
                hid,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr {
                smartInputHotKeyRef = ref
                lastSmartInstalled = smart
            } else {
                lastSmartInstalled = nil
            }
        }
    }

    private static func syncSevenMinuteHotKey(_ seven: SevenMinuteReminderShortcut) {
        guard seven.isEnabled else {
            unregisterSevenMinuteHotKey()
            lastSevenMinuteInstalled = seven
            return
        }
        if seven != lastSevenMinuteInstalled || sevenMinuteHotKeyRef == nil {
            unregisterSevenMinuteHotKey()
            var ref: EventHotKeyRef?
            let hid = EventHotKeyID(signature: signature, id: sevenMinuteHotKeyID)
            let status = RegisterEventHotKey(
                UInt32(seven.keyCode),
                malDazeCarbonModifierMask(for: seven.modifiers),
                hid,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr {
                sevenMinuteHotKeyRef = ref
                lastSevenMinuteInstalled = seven
            } else {
                lastSevenMinuteInstalled = nil
            }
        }
    }

    private static func syncResetIdlePetHotKey(_ resetPet: ResetIdlePetPositionShortcut) {
        guard resetPet.isEnabled else {
            unregisterResetIdlePetHotKey()
            lastResetIdlePetInstalled = resetPet
            return
        }
        if resetPet != lastResetIdlePetInstalled || resetIdlePetHotKeyRef == nil {
            unregisterResetIdlePetHotKey()
            var ref: EventHotKeyRef?
            let hid = EventHotKeyID(signature: signature, id: resetIdlePetHotKeyID)
            let status = RegisterEventHotKey(
                UInt32(resetPet.keyCode),
                malDazeCarbonModifierMask(for: resetPet.modifiers),
                hid,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr {
                resetIdlePetHotKeyRef = ref
                lastResetIdlePetInstalled = resetPet
            } else {
                lastResetIdlePetInstalled = nil
            }
        }
    }
}

// MARK: - NSEvent → Carbon 修饰键

private func malDazeCarbonModifierMask(for modifiers: NSEvent.ModifierFlags) -> UInt32 {
    var mask: UInt32 = 0
    let m = modifiers.intersection(.deviceIndependentFlagsMask)
    if m.contains(.command) { mask |= UInt32(cmdKey) }
    if m.contains(.shift) { mask |= UInt32(shiftKey) }
    if m.contains(.option) { mask |= UInt32(optionKey) }
    if m.contains(.control) { mask |= UInt32(controlKey) }
    return mask
}

// MARK: - Carbon 回调

private func malDazeCarbonGlobalHotKeysCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ theEvent: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let theEvent else { return OSStatus(eventNotHandledErr) }
    var hkCom = EventHotKeyID()
    let err = GetEventParameter(
        theEvent,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hkCom
    )
    guard err == noErr else { return err }
    guard hkCom.signature == 0x4C44_4F47 else {
        return OSStatus(eventNotHandledErr)
    }
    switch hkCom.id {
    case 1:
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: MalDazeBroadcastNotifications.presentDeskPetMenu,
                object: nil
            )
        }
    case 2:
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: MalDazeBroadcastNotifications.openSmartReminderInput,
                object: nil
            )
        }
    case 3:
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: MalDazeBroadcastNotifications.toggleSevenMinuteReminder,
                object: nil
            )
        }
    case 4:
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: MalDazeBroadcastNotifications.resetIdlePetPositionToDefault,
                object: nil
            )
        }
    default:
        return OSStatus(eventNotHandledErr)
    }
    return noErr
}
