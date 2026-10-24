import Foundation
import Testing

/// Spotlight, Siri and Shortcuts read `Assets/Metadata.appintents`, which is generated and committed. This fails when
/// intents change without re-running `scripts/app-intents-metadata.sh`, so Spotlight never shows stale actions.
@Suite(.timeLimit(.minutes(1)))
struct AppIntentsMetadataTests {
    private let intents = ["CaptureCodeIntent", "CapturePlainTextIntent", "CaptureTextIntent", "ReadClipboardImageIntent"]

    @Test func committedMetadataListsEveryActionAndShortcut() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appending(path: "Assets/Metadata.appintents/extract.actionsdata"))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        let actions = (json["actions"] as? [String: Any])?.keys.sorted()
        #expect(actions == intents)
        let shortcuts = (json["autoShortcuts"] as? [[String: Any]])?.compactMap { $0["actionIdentifier"] as? String }.sorted()
        #expect(shortcuts == intents)

        let sources = try FileManager.default.contentsOfDirectory(atPath: root.appending(path: "Sources/Squint/App/Intents").path(percentEncoded: false))
        #expect(sources.filter { $0.hasSuffix("Intent.swift") }.map { String($0.dropLast(6)) }.sorted() == intents)
    }
}
