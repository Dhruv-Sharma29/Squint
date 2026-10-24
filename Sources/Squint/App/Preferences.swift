import Foundation
import Observation

/// Settings that persist across launches, saved to `UserDefaults`.
@MainActor @Observable
final class Preferences {
    var codeMode: Bool {
        didSet { defaults.set(codeMode, forKey: "codeMode") }
    }

    var shortcut: Shortcut {
        didSet { defaults.set(try? JSONEncoder().encode(shortcut), forKey: "shortcut") }
    }

    var playSound: Bool {
        didSet { defaults.set(playSound, forKey: "playSound") }
    }

    /// Off hides the menu bar icon; Squint stays reachable through its shortcut, `squint://` links, and opening the app
    /// again, which shows Settings.
    var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: "showMenuBarIcon") }
    }

    /// Code Mode copies a fenced Markdown block with a language tag.
    var copyAsMarkdown: Bool {
        didSet { defaults.set(copyAsMarkdown, forKey: "copyAsMarkdown") }
    }

    /// Opens the first web address in the copied text.
    var openFirstLink: Bool {
        didSet { defaults.set(openFirstLink, forKey: "openFirstLink") }
    }

    /// Names and terms the text should spell exactly; see `Recognizer.applyingCustomWords`.
    var customWords: [String] {
        didSet { defaults.set(customWords, forKey: "customWords") }
    }

    /// Recognition language for Plain Mode, as a Vision language code; nil detects the language automatically.
    var language: String? {
        didSet { defaults.set(language, forKey: "language") }
    }

    /// Mirrors the system login item, which is the source of truth; see `LaunchAtLogin`.
    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != LaunchAtLogin.isEnabled else { return }
            do {
                try LaunchAtLogin.set(launchAtLogin)
                loginError = nil
            } catch {
                loginError = error.localizedDescription
                launchAtLogin = LaunchAtLogin.isEnabled
            }
        }
    }

    private(set) var loginError: String?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        codeMode = defaults.object(forKey: "codeMode") as? Bool ?? true
        shortcut = defaults.data(forKey: "shortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .standard
        playSound = defaults.bool(forKey: "playSound")
        language = defaults.string(forKey: "language")
        showMenuBarIcon = defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true
        openFirstLink = defaults.bool(forKey: "openFirstLink")
        copyAsMarkdown = defaults.bool(forKey: "copyAsMarkdown")
        customWords = defaults.stringArray(forKey: "customWords") ?? []
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}
