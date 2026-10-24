import Carbon.HIToolbox

/// System-wide shortcut via Carbon: still the only native API for global hotkeys that needs no Accessibility permission.
@MainActor
enum HotKey {
    private static var action: (@MainActor () -> Void)?

    /// Returns false when another app already owns the shortcut.
    static func register(keyCode: Int, modifiers: Int, action: @escaping @MainActor () -> Void) -> Bool {
        Self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { HotKey.action?() }
            return noErr
        }, 1, &spec, nil, nil)
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x5351_4E54), id: 1) // "SQNT"
        return RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &ref) == noErr
    }
}
