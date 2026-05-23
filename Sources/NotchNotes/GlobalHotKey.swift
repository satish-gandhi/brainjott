import Carbon.HIToolbox
import Foundation

final class GlobalHotKey: @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: @MainActor () -> Void

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
        installHandler()
        registerShortcut()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handleHotKey,
            1,
            &eventType,
            userData,
            &handlerRef
        )

        if status != noErr {
            print("Notch Notes: failed to install hotkey handler (\(status)).")
        }
    }

    private func registerShortcut() {
        let hotKeyID = EventHotKeyID(signature: Self.signature("NTCH"), id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            print("Notch Notes: registered Option-Space global shortcut.")
        } else {
            print("Notch Notes: failed to register Option-Space global shortcut (\(status)).")
        }
    }

    private static let handleHotKey: EventHandlerUPP = { _, _, userData in
        guard let userData else {
            return noErr
        }

        let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
        Task { @MainActor in
            hotKey.action()
        }
        return noErr
    }

    private static func signature(_ string: String) -> OSType {
        string.utf8.reduce(0) { partial, character in
            (partial << 8) + OSType(character)
        }
    }
}
