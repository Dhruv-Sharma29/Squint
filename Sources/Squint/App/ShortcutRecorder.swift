import Carbon.HIToolbox
import SwiftUI

/// Click, then press a key combination with ⌘, ⌥ or ⌃. Esc cancels.
struct ShortcutRecorder: View {
    var model: CaptureModel
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .trailing) {
            HStack {
                Button(isRecording ? "Press a shortcut…" : model.preferences.shortcut.displayName, action: toggleRecording)
                    .accessibilityLabel("Capture shortcut")
                    .accessibilityValue(isRecording ? "Recording" : model.preferences.shortcut.displayName)
                if model.preferences.shortcut != .standard, !isRecording {
                    Button("Reset", action: reset)
                }
            }
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        guard !isRecording else { return stopRecording() }
        message = nil
        isRecording = true
        model.suspendShortcut()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
            } else if let shortcut = Shortcut(event: event) {
                stopRecording()
                if !model.changeShortcut(to: shortcut) {
                    message = String(localized: "\(shortcut.displayName) is used by another app.")
                }
            } else {
                message = String(localized: "Include ⌘, ⌥ or ⌃.")
            }
            return nil // swallow the key press
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if isRecording {
            isRecording = false
            model.resumeShortcut()
        }
    }

    private func reset() {
        message = model.changeShortcut(to: .standard) ? nil : String(localized: "\(Shortcut.standard.displayName) is used by another app.")
    }
}
