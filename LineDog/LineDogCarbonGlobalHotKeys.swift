import AppKit
import Carbon.HIToolbox

/// Carbon `RegisterEventHotKey`：桌宠菜单（id 1）与智能输入（id 2）。不依赖「辅助功能」。
enum LineDogCarbonGlobalHotKeys {
    private static let signature: OSType = 0x4C44_4F47 // 'LDOG'
    private static let deskHotKeyID: UInt32 = 1
    private static let smartInputHotKeyID: UInt32 = 2
    private static let sevenMinuteHotKeyID: UInt32 = 3

    private static var deskHotKeyRef: EventHotKeyRef?
    private static var smartInputHotKeyRef: EventHotKeyRef?
    private static var sevenMinuteHotKeyRef: EventHotKeyRef?
    private static var handlerRef: EventHandlerRef?
    private static var defaultsObserver: NSObjectProtocol?
    private static var lastDeskInstalled: DeskPetMenuShortcut?
    private static var lastSmartInstalled: SmartReminderInputShortcut?
    private static var lastSevenMinuteInstalled: SevenMinuteReminderShortcut?

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
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
        Self.handlerRef = nil
        lastDeskInstalled = nil
        lastSmartInstalled = nil
        lastSevenMinuteInstalled = nil
    }

    private static func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var ref: EventHandlerRef?
        typealias HandlerFn = @convention(c) (EventHandlerCallRef?, EventRef?, UnsafeMutableRawPointer?) -> OSStatus
        let upp: EventHandlerUPP = lineDogCarbonGlobalHotKeysCallback as HandlerFn
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

    private static func syncRegistration() {
        installHandlerIfNeeded()
        guard handlerRef != nil else { return }

        let desk = DeskPetMenuShortcut.load()
        if desk != lastDeskInstalled || deskHotKeyRef == nil {
            unregisterDeskHotKey()
            var ref: EventHotKeyRef?
            let hid = EventHotKeyID(signature: signature, id: deskHotKeyID)
            let status = RegisterEventHotKey(
                UInt32(desk.keyCode),
                lineDogCarbonModifierMask(for: desk.modifiers),
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

        let smart = SmartReminderInputShortcut.load()
        if smart != lastSmartInstalled || smartInputHotKeyRef == nil {
            unregisterSmartInputHotKey()
            var ref: EventHotKeyRef?
            let hid = EventHotKeyID(signature: signature, id: smartInputHotKeyID)
            let status = RegisterEventHotKey(
                UInt32(smart.keyCode),
                lineDogCarbonModifierMask(for: smart.modifiers),
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

        let seven = SevenMinuteReminderShortcut.load()
        if seven != lastSevenMinuteInstalled || sevenMinuteHotKeyRef == nil {
            unregisterSevenMinuteHotKey()
            var ref: EventHotKeyRef?
            let hid = EventHotKeyID(signature: signature, id: sevenMinuteHotKeyID)
            let status = RegisterEventHotKey(
                UInt32(seven.keyCode),
                lineDogCarbonModifierMask(for: seven.modifiers),
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
}

// MARK: - NSEvent → Carbon 修饰键

private func lineDogCarbonModifierMask(for modifiers: NSEvent.ModifierFlags) -> UInt32 {
    var mask: UInt32 = 0
    let m = modifiers.intersection(.deviceIndependentFlagsMask)
    if m.contains(.command) { mask |= UInt32(cmdKey) }
    if m.contains(.shift) { mask |= UInt32(shiftKey) }
    if m.contains(.option) { mask |= UInt32(optionKey) }
    if m.contains(.control) { mask |= UInt32(controlKey) }
    return mask
}

// MARK: - Carbon 回调

private func lineDogCarbonGlobalHotKeysCallback(
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
                name: LineDogBroadcastNotifications.presentDeskPetMenu,
                object: nil
            )
        }
    case 2:
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: LineDogBroadcastNotifications.openSmartReminderInput,
                object: nil
            )
        }
    case 3:
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: LineDogBroadcastNotifications.toggleSevenMinuteReminder,
                object: nil
            )
        }
    default:
        return OSStatus(eventNotHandledErr)
    }
    return noErr
}
