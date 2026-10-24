import AppIntents
import AppKit

/// Owns the model so the global hotkey, the menu, Settings, `squint://` links and App Intents (Spotlight,
/// Shortcuts) all reach the same instance.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = CaptureModel()
    private lazy var settings = SettingsPanel(model: model)

    override init() {
        super.init()
        let model = model
        AppDependencyManager.shared.add(dependency: model)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if LinkCommand(url) == .settings {
                showSettings()
            } else {
                Task { await model.open(url) }
            }
        }
    }

    /// Opening Squint again (Finder, Spotlight) shows Settings: with the menu bar icon hidden, that's the way back to it.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func showSettings() {
        settings.present()
    }
}
