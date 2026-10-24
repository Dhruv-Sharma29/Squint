import SwiftUI

struct MenuContent: View {
    var model: CaptureModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var preferences = model.preferences

        Button("Capture Text", systemImage: "text.viewfinder", action: capture)
            .keyboardShortcut(preferences.shortcut.keyboardShortcut)
            .disabled(model.isBusy)
        Button("Read Clipboard Image", systemImage: "doc.on.clipboard", action: readClipboard)
            .disabled(model.isBusy)
        // A Toggle's tick goes in the menu's state column, left of the icons above. Drawing it as the item's
        // icon lines it up with them; the title stays aligned either way.
        Button {
            preferences.codeMode.toggle()
        } label: {
            if preferences.codeMode {
                Label("Code Mode", systemImage: "checkmark")
            } else {
                Text("Code Mode")
            }
        }
        .accessibilityValue(preferences.codeMode ? Text("On") : Text("Off"))

        if case .failed(let message) = model.status {
            Divider()
            Text(message)
        }
        if !model.hotKeyAvailable {
            Text("\(preferences.shortcut.displayName) is in use by another app. Choose another shortcut in Settings.")
        }

        Divider()
        Button("Settings…", action: showSettings)
            .keyboardShortcut(",")
        Button("Quit Squint") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func capture() {
        Task { await model.capture() }
    }

    private func readClipboard() {
        Task { await model.readClipboard() }
    }

    /// A menu bar app isn't frontmost, so bring it forward or the window opens behind others.
    private func showSettings() {
        NSApplication.shared.activate()
        openSettings()
    }
}
