import AppIntents
import AppKit

/// Owns the model so the global hotkey, the menu, Settings, `squint://` links and App Intents (Spotlight,
/// Shortcuts) all reach the same instance.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = CaptureModel()

    override init() {
        super.init()
        let model = model
        AppDependencyManager.shared.add(dependency: model)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Task { await model.open(url) }
        }
    }
}
