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

        switch model.status {
        case .failed(let message):
            Divider()
            Text(message)
        case .needsPermission:
            Divider()
            Text("Squint needs Screen Recording permission")
            Button("Open Screen Recording Settings…", action: model.openScreenRecordingSettings)
            Text("Then quit and reopen Squint")
        case .idle, .copied:
            EmptyView()
        }
        if !model.hotKeyAvailable {
            Text("\(preferences.shortcut.displayName) is used by another app")
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
