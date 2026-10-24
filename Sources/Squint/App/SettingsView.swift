import SwiftUI

struct SettingsView: View {
    var model: CaptureModel

    var body: some View {
        @Bindable var preferences = model.preferences

        Form {
            Section("Capture") {
                LabeledContent("Shortcut") {
                    ShortcutRecorder(model: model)
                }
                Toggle("Code Mode", isOn: $preferences.codeMode)
                Toggle("Play a sound when text is copied", isOn: $preferences.playSound)
            }

            Section {
                Picker("Language", selection: $preferences.language) {
                    Text("Automatic").tag(String?.none)
                    Divider()
                    ForEach(Recognizer.supportedLanguages, id: \.self) { code in
                        Text(Locale.current.localizedString(forIdentifier: code) ?? code).tag(Optional(code))
                    }
                }
            } header: {
                Text("Plain Mode")
            } footer: {
                Text("Code Mode always reads Latin script, so code isn't turned into another language's characters.")
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Open at login", isOn: $preferences.launchAtLogin)
                if let error = preferences.loginError {
                    Text(error)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}
