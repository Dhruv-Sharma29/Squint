import AppIntents

/// Squint's actions in Spotlight (type "Squint"), Siri and the Shortcuts app.
struct SquintShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CaptureTextIntent(),
                    phrases: ["Capture text with \(.applicationName)", "\(.applicationName) capture"],
                    shortTitle: "Capture Text", systemImageName: "text.viewfinder")
        AppShortcut(intent: CaptureCodeIntent(),
                    phrases: ["Capture code with \(.applicationName)", "Copy code from the screen with \(.applicationName)"],
                    shortTitle: "Capture Code", systemImageName: "chevron.left.forwardslash.chevron.right")
        AppShortcut(intent: CapturePlainTextIntent(),
                    phrases: ["Capture plain text with \(.applicationName)"],
                    shortTitle: "Capture Plain Text", systemImageName: "text.alignleft")
        AppShortcut(intent: ReadClipboardImageIntent(),
                    phrases: ["Read clipboard image with \(.applicationName)"],
                    shortTitle: "Read Clipboard Image", systemImageName: "doc.on.clipboard")
    }

    static let shortcutTileColor: ShortcutTileColor = .navy
}
