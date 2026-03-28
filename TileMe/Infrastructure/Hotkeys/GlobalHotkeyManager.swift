import AppKit
@preconcurrency import Carbon.HIToolbox
import Foundation

struct GlobalHotkeyRegistration {
    let identifier: String
    let keyCode: UInt16
    let modifiersRawValue: UInt
    let handler: @MainActor () -> Void
}

struct HotkeyRegistrationFailure: Equatable {
    let identifier: String
    let reason: String
}

protocol GlobalHotkeyManaging {
    @MainActor
    func replaceRegistrations(_ registrations: [GlobalHotkeyRegistration]) -> [HotkeyRegistrationFailure]

    @MainActor
    func unregisterAll()
}

@MainActor
final class CarbonGlobalHotkeyManager: GlobalHotkeyManaging {
    private static let signature: OSType = 0x54494C45
    private static let hotKeyHandler: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else {
            return OSStatus(eventNotHandledErr)
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            return status
        }

        let manager = Unmanaged<CarbonGlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
        return MainActor.assumeIsolated {
            manager.handleHotKeyID(hotKeyID.id)
        }
    }

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: @MainActor () -> Void] = [:]
    private var eventHandlerRef: EventHandlerRef?

    init() {
        installEventHandlerIfNeeded()
    }

    func replaceRegistrations(_ registrations: [GlobalHotkeyRegistration]) -> [HotkeyRegistrationFailure] {
        unregisterAll()

        var failures: [HotkeyRegistrationFailure] = []
        for (index, registration) in registrations.enumerated() {
            let hotKeyIDValue = UInt32(index + 1)
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: hotKeyIDValue)

            let status = RegisterEventHotKey(
                UInt32(registration.keyCode),
                carbonModifiers(from: registration.modifiersRawValue),
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            guard status == noErr, let hotKeyRef else {
                failures.append(
                    HotkeyRegistrationFailure(
                        identifier: registration.identifier,
                        reason: "Registration failed with Carbon status \(status)."
                    )
                )
                continue
            }

            hotKeyRefs[hotKeyIDValue] = hotKeyRef
            handlers[hotKeyIDValue] = registration.handler
        }

        return failures
    }

    func unregisterAll() {
        for hotKeyRef in hotKeyRefs.values {
            UnregisterEventHotKey(hotKeyRef)
        }

        hotKeyRefs.removeAll()
        handlers.removeAll()
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else {
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.hotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func handleHotKeyID(_ hotKeyID: UInt32) -> OSStatus {
        guard let handler = handlers[hotKeyID] else {
            return OSStatus(eventNotHandledErr)
        }

        handler()
        return noErr
    }

    private func carbonModifiers(from rawValue: UInt) -> UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: rawValue)
        var carbonFlags: UInt32 = 0

        if flags.contains(.command) {
            carbonFlags |= UInt32(cmdKey)
        }

        if flags.contains(.option) {
            carbonFlags |= UInt32(optionKey)
        }

        if flags.contains(.control) {
            carbonFlags |= UInt32(controlKey)
        }

        if flags.contains(.shift) {
            carbonFlags |= UInt32(shiftKey)
        }

        return carbonFlags
    }
}
