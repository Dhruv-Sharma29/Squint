import Carbon.HIToolbox
import Foundation
import Testing
@testable import Squint

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PreferencesTests {
    private let suite = "squint-tests-\(UUID().uuidString)"

    @Test func defaultsForNewUsers() throws {
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.codeMode)
        #expect(preferences.shortcut == .standard)
        #expect(!preferences.playSound)
        #expect(preferences.language == nil)
        #expect(preferences.showMenuBarIcon)
        #expect(!preferences.openFirstLink)
        #expect(!preferences.copyAsMarkdown)
        #expect(preferences.customWords.isEmpty)
    }

    @Test func settingsPersistAcrossLaunches() throws {
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let custom = Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | optionKey), key: "S")

        let first = Preferences(defaults: defaults)
        first.codeMode = false
        first.shortcut = custom
        first.playSound = true
        first.language = "hi-IN"
        first.showMenuBarIcon = false
        first.openFirstLink = true
        first.copyAsMarkdown = true
        first.customWords = ["Kubernetes", "Flaxmere"]

        let relaunched = Preferences(defaults: defaults)
        #expect(!relaunched.codeMode)
        #expect(relaunched.shortcut == custom)
        #expect(relaunched.playSound)
        #expect(relaunched.language == "hi-IN")
        #expect(!relaunched.showMenuBarIcon)
        #expect(relaunched.openFirstLink)
        #expect(relaunched.copyAsMarkdown)
        #expect(relaunched.customWords == ["Kubernetes", "Flaxmere"])

        relaunched.language = nil
        #expect(Preferences(defaults: defaults).language == nil)
    }
}
