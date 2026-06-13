import AppKit
import Carbon.HIToolbox

/// Carbon `RegisterEventHotKey`：桌宠菜单（id 1）、智能输入（id 2）、独立倒计时（id 3）、桌宠复位（id 4）。不依赖「辅助功能」。
enum MalDazeCarbonGlobalHotKeys {
    static let signature: OSType = 0x4C44_4F47 // 'LDOG'

    static var registrationSlots: [CarbonHotKeyRegistrationSlot] {
        [
            CarbonHotKeyRegistrationSlot(
                id: 1,
                notificationName: MalDazeBroadcastNotifications.presentDeskPetMenu,
                loadShortcut: { CarbonHotKeyShortcut(DeskPetMenuShortcut.load()) }
            ),
            CarbonHotKeyRegistrationSlot(
                id: 2,
                notificationName: MalDazeBroadcastNotifications.openSmartReminderInput,
                loadShortcut: { CarbonHotKeyShortcut(SmartReminderInputShortcut.load()) }
            ),
            CarbonHotKeyRegistrationSlot(
                id: 3,
                notificationName: MalDazeBroadcastNotifications.toggleSevenMinuteReminder,
                loadShortcut: { CarbonHotKeyShortcut(SevenMinuteReminderShortcut.load()) }
            ),
            CarbonHotKeyRegistrationSlot(
                id: 4,
                notificationName: MalDazeBroadcastNotifications.resetIdlePetPositionToDefault,
                loadShortcut: { CarbonHotKeyShortcut(ResetIdlePetPositionShortcut.load()) }
            )
        ]
    }

    static var registrationSlotDescriptors: [CarbonHotKeyRegistrationSlotDescriptor] {
        registrationSlots.map(\.descriptor)
    }

    nonisolated(unsafe) private static var registrationStates: [UInt32: CarbonHotKeyRuntimeState] = [:]
    nonisolated(unsafe) private static var handlerRef: EventHandlerRef?
    nonisolated(unsafe) private static var defaultsObserver: NSObjectProtocol?

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
        for slot in registrationSlots {
            unregisterHotKey(slot.id)
        }
        registrationStates.removeAll()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
        Self.handlerRef = nil
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

    private static func unregisterHotKey(_ id: UInt32) {
        if let ref = registrationStates[id]?.ref {
            UnregisterEventHotKey(ref)
        }
        registrationStates[id, default: CarbonHotKeyRuntimeState()].ref = nil
    }

    private static func syncRegistration() {
        installHandlerIfNeeded()
        guard handlerRef != nil else { return }

        for slot in registrationSlots {
            syncHotKey(slot)
        }
    }

    private static func syncHotKey(_ slot: CarbonHotKeyRegistrationSlot) {
        let loadedShortcut = slot.loadShortcut()
        var runtimeState = registrationStates[slot.id] ?? CarbonHotKeyRuntimeState()
        let plan = slot.plan(for: loadedShortcut, state: runtimeState.registrationState)

        if plan.shouldUnregister, let ref = runtimeState.ref {
            UnregisterEventHotKey(ref)
            runtimeState.ref = nil
        }

        if let request = plan.registrationRequest {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(request.keyCode),
                malDazeCarbonModifierMask(for: request.modifiers),
                request.hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            let nextState = plan.stateAfterRegistration(succeeded: status == noErr)
            runtimeState.installedShortcut = nextState.installedShortcut
            runtimeState.ref = nextState.hasHotKeyRef ? ref : nil
        } else if let nextState = plan.stateWithoutRegistration {
            runtimeState.installedShortcut = nextState.installedShortcut
            if !nextState.hasHotKeyRef {
                runtimeState.ref = nil
            }
        }

        registrationStates[slot.id] = runtimeState
    }

    static func notificationName(forHotKeyID id: UInt32) -> Notification.Name? {
        registrationSlots.first { $0.id == id }?.notificationName
    }
}

struct CarbonHotKeyRegistrationSlotDescriptor: Equatable {
    let id: UInt32
    let signature: OSType
    let notificationName: Notification.Name
}

struct CarbonHotKeyRegistrationSlot {
    let id: UInt32
    let signature: OSType
    let notificationName: Notification.Name
    let loadShortcut: () -> CarbonHotKeyShortcut

    var descriptor: CarbonHotKeyRegistrationSlotDescriptor {
        CarbonHotKeyRegistrationSlotDescriptor(
            id: id,
            signature: signature,
            notificationName: notificationName
        )
    }

    init(
        id: UInt32,
        signature: OSType = MalDazeCarbonGlobalHotKeys.signature,
        notificationName: Notification.Name,
        loadShortcut: @escaping () -> CarbonHotKeyShortcut
    ) {
        self.id = id
        self.signature = signature
        self.notificationName = notificationName
        self.loadShortcut = loadShortcut
    }

    func plan(
        for loadedShortcut: CarbonHotKeyShortcut,
        state: CarbonHotKeyRegistrationState
    ) -> CarbonHotKeyRegistrationPlan {
        guard loadedShortcut.isEnabled else {
            return CarbonHotKeyRegistrationPlan(
                shouldUnregister: state.hasHotKeyRef,
                registrationRequest: nil,
                stateWithoutRegistration: CarbonHotKeyRegistrationState(
                    installedShortcut: loadedShortcut,
                    hasHotKeyRef: false
                )
            )
        }

        guard loadedShortcut != state.installedShortcut || !state.hasHotKeyRef else {
            return CarbonHotKeyRegistrationPlan(
                shouldUnregister: false,
                registrationRequest: nil,
                stateWithoutRegistration: state
            )
        }

        return CarbonHotKeyRegistrationPlan(
            shouldUnregister: state.hasHotKeyRef,
            registrationRequest: CarbonHotKeyRegistrationRequest(
                hotKeyID: EventHotKeyID(signature: signature, id: id),
                keyCode: loadedShortcut.keyCode,
                modifiers: loadedShortcut.modifiers
            ),
            stateWithoutRegistration: nil
        )
    }
}

struct CarbonHotKeyShortcut: Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags

    var isEnabled: Bool {
        !modifiers.intersection([.command, .option, .control, .shift]).isEmpty
    }

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(.deviceIndependentFlagsMask)
    }

    init(_ shortcut: DeskPetMenuShortcut) {
        self.init(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
    }

    init(_ shortcut: SmartReminderInputShortcut) {
        self.init(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
    }

    init(_ shortcut: SevenMinuteReminderShortcut) {
        self.init(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
    }

    init(_ shortcut: ResetIdlePetPositionShortcut) {
        self.init(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
    }
}

struct CarbonHotKeyRegistrationState: Equatable {
    var installedShortcut: CarbonHotKeyShortcut?
    var hasHotKeyRef: Bool
}

struct CarbonHotKeyRegistrationRequest: Equatable {
    var hotKeyID: EventHotKeyID
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags

    var shortcut: CarbonHotKeyShortcut {
        CarbonHotKeyShortcut(keyCode: keyCode, modifiers: modifiers)
    }

    static func == (
        lhs: CarbonHotKeyRegistrationRequest,
        rhs: CarbonHotKeyRegistrationRequest
    ) -> Bool {
        lhs.hotKeyID.signature == rhs.hotKeyID.signature
            && lhs.hotKeyID.id == rhs.hotKeyID.id
            && lhs.keyCode == rhs.keyCode
            && lhs.modifiers == rhs.modifiers
    }
}

struct CarbonHotKeyRegistrationPlan: Equatable {
    var shouldUnregister: Bool
    var registrationRequest: CarbonHotKeyRegistrationRequest?
    var stateWithoutRegistration: CarbonHotKeyRegistrationState?

    func stateAfterRegistration(succeeded: Bool) -> CarbonHotKeyRegistrationState {
        guard succeeded, let registrationRequest else {
            return CarbonHotKeyRegistrationState(installedShortcut: nil, hasHotKeyRef: false)
        }
        return CarbonHotKeyRegistrationState(
            installedShortcut: registrationRequest.shortcut,
            hasHotKeyRef: true
        )
    }
}

private struct CarbonHotKeyRuntimeState {
    var ref: EventHotKeyRef?
    var installedShortcut: CarbonHotKeyShortcut?

    var registrationState: CarbonHotKeyRegistrationState {
        CarbonHotKeyRegistrationState(
            installedShortcut: installedShortcut,
            hasHotKeyRef: ref != nil
        )
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
    guard hkCom.signature == MalDazeCarbonGlobalHotKeys.signature else {
        return OSStatus(eventNotHandledErr)
    }
    guard let notificationName = MalDazeCarbonGlobalHotKeys.notificationName(forHotKeyID: hkCom.id) else {
        return OSStatus(eventNotHandledErr)
    }
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: notificationName, object: nil)
    }
    return noErr
}
