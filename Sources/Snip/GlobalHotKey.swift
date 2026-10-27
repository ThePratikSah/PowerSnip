import AppKit
import Carbon.HIToolbox

/// Manages system-wide global hotkey for screen snippet capture.
/// Designated shortcut: Cmd + Option + Shift + 4 (does NOT override macOS Cmd+Shift+4 or Cmd+Shift+3).
@MainActor
final class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()

    private var hotKeyRefs: [EventHotKeyRef] = []
    var onHotKeyTriggered: (() -> Void)?
    private var isHandlerInstalled = false

    func register(action: @escaping () -> Void) {
        self.onHotKeyTriggered = action
        unregister()

        let dispatcher = GetEventDispatcherTarget()

        // Designated shortcut only: Cmd + Option + Shift + 4
        let id1 = EventHotKeyID(signature: OSType(0x534E5031), id: 1) // 'SNP1', 1
        var ref1: EventHotKeyRef?
        let status1 = RegisterEventHotKey(
            UInt32(kVK_ANSI_4),
            UInt32(cmdKey | optionKey | shiftKey),
            id1,
            dispatcher,
            0,
            &ref1
        )
        if status1 == noErr, let r = ref1 {
            hotKeyRefs.append(r)
            print("Registered designated global hotkey Cmd+Option+Shift+4 (noErr)")
        } else {
            print("Notice: Cmd+Option+Shift+4 status \(status1)")
        }

        if !isHandlerInstalled {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )

            InstallEventHandler(dispatcher, { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                if let event = event {
                    GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotKeyID
                    )
                }
                Task { @MainActor in
                    GlobalHotKeyManager.shared.onHotKeyTriggered?()
                }
                return noErr
            }, 1, &eventType, nil, nil)
            isHandlerInstalled = true
        }
    }

    func unregister() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }
}
