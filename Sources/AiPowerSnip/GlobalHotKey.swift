import AppKit
import Carbon.HIToolbox

/// Manages the system-wide global hotkey (Cmd + Option + Shift + 4).
/// Works from any application without needing extra permissions.
@MainActor
final class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    var onHotKeyTriggered: (() -> Void)?

    func register(action: @escaping () -> Void) {
        self.onHotKeyTriggered = action

        // Unregister previous if any
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }

        // 'SNIP', 1
        let hotKeyID = EventHotKeyID(signature: OSType(0x534E4950), id: 1)
        // Cmd + Option + Shift + 4
        let modifiers = UInt32(cmdKey | optionKey | shiftKey)
        let keyCode = UInt32(kVK_ANSI_4)

        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            print("Failed to register global hotkey Cmd+Option+Shift+4: status \(status)")
        } else {
            print("Registered global hotkey Cmd+Option+Shift+4")
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(GetApplicationEventTarget(), { (_, _, _) -> OSStatus in
            Task { @MainActor in
                GlobalHotKeyManager.shared.onHotKeyTriggered?()
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}
