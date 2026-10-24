import SwiftUI

struct SettingsView: View {
    var model: CaptureModel
    /// macOS applies a new grant only after relaunch, so this is re-read whenever Squint becomes active.
    @State private var screenRecordingAllowed: Bool
    /// The custom words as typed, comma-separated.
    @State private var words: String

    init(model: CaptureModel, screenRecordingAllowed: Bool = CGPreflightScreenCaptureAccess()) {
        self.model = model
        _screenRecordingAllowed = State(initialValue: screenRecordingAllowed)
        _words = State(initialValue: model.preferences.customWords.joined(separator: ", "))
    }

    private static let website = URL(string: "https://dhruv-sharma29.github.io/Squint/")
    private var subtitle: String {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            String(localized: "Screen OCR for code, version \(version)")
        } else {
            String(localized: "Screen OCR for code, development build")
        }
    }

    var body: some View {
        @Bindable var preferences = model.preferences

        Form {
            Section {
                HStack {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 52, height: 52)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text("Squint")
                            .font(.title3)
                            .bold()
                        Text(subtitle)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let website = Self.website {
                        Link("Website", destination: website)
                    }
                }
            }

            Section("Capture") {
                LabeledContent {
                    ShortcutRecorder(model: model)
                } label: {
                    SettingsLabel(title: "Shortcut", detail: "Starts a capture from any app", systemName: "keyboard", color: .blue)
                }
                Toggle(isOn: $preferences.codeMode) {
                    SettingsLabel(title: "Code Mode", detail: "Keeps indentation, blank lines and brackets",
                                  systemName: "chevron.left.forwardslash.chevron.right", color: .indigo)
                }
                Toggle(isOn: $preferences.copyAsMarkdown) {
                    SettingsLabel(title: "Copy as Markdown", detail: "Code goes in a fenced block with its language",
                                  systemName: "number", color: .purple)
                }
                Toggle(isOn: $preferences.playSound) {
                    SettingsLabel(title: "Sound when text is copied", systemName: "speaker.wave.2.fill", color: .pink)
                }
                Toggle(isOn: $preferences.openFirstLink) {
                    SettingsLabel(title: "Open links", detail: "Opens the first web address in the copied text",
                                  systemName: "link", color: .cyan)
                }
                LabeledContent {
                    TextField("Custom words", text: $words, prompt: Text("Kubernetes, MyCompany"))
                        .labelsHidden()
                        .onChange(of: words) {
                            model.preferences.customWords = words.split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        }
                } label: {
                    SettingsLabel(title: "Custom words", detail: "Spelled exactly, even when misread by a letter",
                                  systemName: "character.book.closed", color: .brown)
                }
            }

            if TableReader.isAvailable {
                Section("Tables") {
                    Picker(selection: $preferences.tableFormat) {
                        Text("Markdown").tag(TableReader.Format.markdown)
                        Text("Tab-separated").tag(TableReader.Format.tsv)
                    } label: {
                        SettingsLabel(title: "Copy tables as", detail: "Tab-separated pastes into a spreadsheet",
                                      systemName: "tablecells", color: .mint)
                    }
                }
            }

            Section("Plain Mode") {
                Picker(selection: $preferences.language) {
                    Text("Automatic").tag(String?.none)
                    Divider()
                    ForEach(Recognizer.supportedLanguages, id: \.self) { code in
                        Text(Locale.current.localizedString(forIdentifier: code) ?? code).tag(Optional(code))
                    }
                } label: {
                    SettingsLabel(title: "Language", detail: "Used when Code Mode is off", systemName: "globe", color: .teal)
                }
            }

            Section("System") {
                LabeledContent {
                    if screenRecordingAllowed {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Open Settings…", action: model.openScreenRecordingSettings)
                    }
                } label: {
                    SettingsLabel(title: "Screen Recording",
                                  detail: screenRecordingAllowed ? "Squint can see the area you select" : "Needed to capture. Reopen Squint after allowing it.",
                                  systemName: "rectangle.dashed.badge.record", color: .orange)
                }
                Toggle(isOn: $preferences.keepHistory) {
                    SettingsLabel(title: "Keep history", detail: "The last \(CaptureHistory.limit) captures, only on this Mac. Off deletes them.",
                                  systemName: "clock.arrow.circlepath", color: .indigo)
                }
                .onChange(of: preferences.keepHistory) { _, keep in model.setKeepHistory(keep) }
                if preferences.keepHistory {
                    Button("Clear History", action: model.history.clear)
                        .disabled(model.history.entries.isEmpty)
                }
                Toggle(isOn: $preferences.showMenuBarIcon) {
                    SettingsLabel(title: "Show in menu bar", detail: "When hidden, open Squint again to see Settings",
                                  systemName: "menubar.rectangle", color: .gray)
                }
                Toggle(isOn: $preferences.launchAtLogin) {
                    SettingsLabel(title: "Open at login", systemName: "power", color: .green)
                }
                if let error = preferences.loginError {
                    Text(error)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            screenRecordingAllowed = CGPreflightScreenCaptureAccess()
        }
    }
}
