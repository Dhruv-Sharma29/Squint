import AppKit

/// Owns the model so the global hotkey, the menu, Settings and `squint://` links all reach the same instance.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = CaptureModel()

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Task { await model.open(url) }
        }
    }
}
