import Carbon.HIToolbox

/// System-wide shortcut via Carbon: still the only native API for global hotkeys that needs no Accessibility permission.
@MainActor
enum HotKey {
    private static var action: (@MainActor () -> Void)?
    private static var reference: EventHotKeyRef?
    private static var handlerInstalled = false

    /// Registers `shortcut`, replacing any previous one. Returns false when another app already owns it.
    static func register(_ shortcut: Shortcut, action: @escaping @MainActor () -> Void) -> Bool {
        Self.action = action
        installHandler()
        unregister()
        var reference: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x5351_4E54), id: 1) // "SQNT"
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &reference)
        Self.reference = status == noErr ? reference : nil
        return status == noErr
    }

    /// Releases the shortcut, for example while a new one is being recorded.
    static func unregister() {
        if let reference {
            UnregisterEventHotKey(reference)
        }
        reference = nil
    }

    private static func installHandler() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { HotKey.action?() }
            return noErr
        }, 1, &spec, nil, nil)
        handlerInstalled = true
    }
}
