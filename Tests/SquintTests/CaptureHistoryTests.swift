import AppKit
import Foundation
import Testing
@testable import Squint

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CaptureHistoryTests {
    private let file = URL.temporaryDirectory.appending(path: "squint-history-\(UUID().uuidString)/history.json")

    @Test func keepsTheLastCapturesNewestFirstAcrossLaunches() throws {
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let history = CaptureHistory(file: file)
        for n in 1...25 { history.add("capture \(n)") }
        history.add("capture 25") // the same again isn't added twice
        #expect(history.entries.count == CaptureHistory.limit)
        #expect(history.entries.first?.text == "capture 25")
        #expect(CaptureHistory(file: file).entries == history.entries)
        // Only this user can read it.
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path(percentEncoded: false))[.posixPermissions] as? Int
        #expect(permissions == 0o600)
        history.clear()
        #expect(CaptureHistory(file: file).entries.isEmpty)
    }

    @Test func capturesAreKeptOnlyWhenHistoryIsOn() async throws {
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("squint-history-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let defaults = try #require(UserDefaults(suiteName: "squint-history-\(UUID().uuidString)"))
        let model = CaptureModel(preferences: Preferences(defaults: defaults), history: CaptureHistory(file: file),
                                 pasteboard: pasteboard, screenAccess: { true },
                                 captureRegion: { try CodeImage.write("let x = 1") }, registersHotKey: false)
        await model.capture()
        #expect(model.history.entries.isEmpty) // off by default

        model.setKeepHistory(true)
        await model.capture()
        #expect(model.history.entries.map(\.text) == ["let x = 1"])

        model.setKeepHistory(false) // off deletes what was kept
        #expect(model.history.entries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
    }

    @Test func menuTitlesAreTheFirstLineShortened() {
        let entry = CaptureHistory.Entry(text: "\n   function averyveryverylongfunctionname(argumentOne) {\n}", date: .now)
        #expect(MenuContent.title(of: entry) == "function averyveryverylongfunctionname(…")
    }
}
