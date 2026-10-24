import AppKit
import SwiftUI

/// The Settings window. Squint opens it itself rather than through SwiftUI's `Settings` scene: a menu bar app isn't
/// the active app, and the scene's window opened behind whatever app was in front.
final class SettingsPanel: NSWindow {
    init(model: CaptureModel) {
        super.init(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        let content = NSHostingController(rootView: SettingsView(model: model))
        content.sizingOptions = [.preferredContentSize]
        contentViewController = content
        setContentSize(content.view.fittingSize)
        title = String(localized: "Squint Settings")
        isReleasedWhenClosed = false
        center()
    }

    /// Brings Settings to the front with keyboard focus, even though a menu bar app usually isn't the active app.
    func present() {
        NSApplication.shared.activate()
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }

    /// Esc closes Settings, like a standard settings window.
    override func cancelOperation(_ sender: Any?) {
        close()
    }

    /// ⌘W closes Settings. A menu bar app has no Window menu to provide it.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command, event.charactersIgnoringModifiers == "w" {
            close()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
