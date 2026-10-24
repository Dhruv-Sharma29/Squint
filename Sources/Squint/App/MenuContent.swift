import SwiftUI

struct MenuContent: View {
    @Bindable var model: CaptureModel

    var body: some View {
        Button("Capture Text", systemImage: "text.viewfinder", action: capture)
            .keyboardShortcut("2", modifiers: [.command, .shift])
        Button("Read Clipboard Image", systemImage: "doc.on.clipboard", action: readClipboard)
        Toggle("Code Mode", isOn: $model.codeMode)

        if case .failed(let message) = model.status {
            Divider()
            Text(message)
        }
        if !model.hotKeyAvailable {
            Text("⌘⇧2 is in use by another app; capture from this menu or a squint://capture link instead.")
        }

        Divider()
        Button("Quit Squint") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func capture() {
        Task { await model.capture() }
    }

    private func readClipboard() {
        Task { await model.readClipboard() }
    }
}
