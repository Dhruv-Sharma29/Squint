import SwiftUI

struct MenuContent: View {
    var model: CaptureModel
    var showSettings: () -> Void

    var body: some View {
        @Bindable var preferences = model.preferences

        Button("Capture Text", systemImage: "text.viewfinder", action: capture)
            .keyboardShortcut(preferences.shortcut.keyboardShortcut)
            .disabled(model.isBusy)
        Button("Read Clipboard Image", systemImage: "doc.on.clipboard", action: readClipboard)
            .disabled(model.isBusy)
        if TableReader.isAvailable {
            Button("Capture Table", systemImage: "tablecells") { Task { await model.captureTable() } }
                .disabled(model.isBusy)
        }
        if let scrolled = model.scrollCapture {
            let lines = scrolled.isEmpty ? 0 : scrolled.split(separator: "\n", omittingEmptySubsequences: false).count
            Button("Finish Scroll Capture (\(lines) lines)", systemImage: "stop.circle", action: model.finishScrollCapture)
        } else {
            Button("Start Scroll Capture", systemImage: "arrow.down.doc", action: model.startScrollCapture)
        }
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

        if model.preferences.keepHistory, !model.history.entries.isEmpty {
            Menu("History") {
                ForEach(model.history.entries.prefix(10)) { entry in
                    Button(Self.title(of: entry)) { model.copyAgain(entry) }
                }
                Divider()
                Button("Clear History", action: model.history.clear)
            }
        }

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

    /// A capture's first line with text, short enough for a menu.
    static func title(of entry: CaptureHistory.Entry) -> String {
        let line = entry.text.split(separator: "\n").first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return line.count > 40 ? String(line.prefix(39)) + "…" : line
    }

    private func capture() {
        Task { await model.capture() }
    }

    private func readClipboard() {
        Task { await model.readClipboard() }
    }

}
