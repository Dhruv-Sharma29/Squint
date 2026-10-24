import AppKit
import Foundation
import Testing
@testable import Squint

/// The capture → recognize → copy journeys, end to end through Vision and the code-layout pass. Only the system's
/// selection overlay is replaced (by a rendered screenshot), and a private pasteboard stands in for the clipboard.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CaptureModelTests {
    static let code = """
        function sum(arr) {
          let total = 0;
          for (const x of arr) {
            total += x;
          }
          return total;
        }
        """
    /// Leading spaces per line of `code`: the layout Code Mode must keep.
    static let indents = [0, 2, 2, 4, 2, 2, 0]

    private let pasteboard = NSPasteboard(name: NSPasteboard.Name("squint-model-tests-\(UUID().uuidString)"))
    private let suite = "squint-model-tests-\(UUID().uuidString)"

    private struct OverlayOpened: Error {}

    private func makeModel(screenAccess: Bool = true, capture: @escaping @MainActor () async throws -> URL?) throws -> CaptureModel {
        let defaults = try #require(UserDefaults(suiteName: suite))
        return CaptureModel(preferences: Preferences(defaults: defaults), pasteboard: pasteboard,
                            screenAccess: { screenAccess }, captureRegion: capture, registersHotKey: false)
    }

    private func indents(_ text: String?) -> [Int]? {
        text?.components(separatedBy: "\n").map { $0.prefix { $0 == " " }.count }
    }

    @Test func captureCopiesCodeWithItsLayout() async throws {
        defer { pasteboard.releaseGlobally() }
        let screenshot = try CodeImage.write(Self.code)
        let model = try makeModel { screenshot }

        let text = await model.capture()

        #expect(indents(text) == Self.indents)
        #expect(text?.contains("total += x;") == true)
        #expect(pasteboard.string(forType: .string) == text)
        #expect(model.status == .copied)
        #expect(!model.isBusy)
        #expect(!FileManager.default.fileExists(atPath: screenshot.path(percentEncoded: false))) // private data deleted
    }

    @Test func cancelledCaptureLeavesClipboardAlone() async throws {
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("before", forType: .string)
        let model = try makeModel { nil } // Esc in the overlay

        #expect(await model.capture() == nil)
        #expect(model.status == .idle)
        #expect(pasteboard.string(forType: .string) == "before")
    }

    @Test func missingPermissionShowsTheFixWithoutOpeningTheOverlay() async throws {
        let model = try makeModel(screenAccess: false) { throw OverlayOpened() }

        #expect(await model.capture() == nil)
        #expect(model.status == .needsPermission) // not .failed(OverlayOpened): the overlay never ran
    }

    @Test func secondCaptureWhileBusyIsIgnored() async throws {
        defer { pasteboard.releaseGlobally() }
        let screenshot = try CodeImage.write(Self.code)
        let model = try makeModel {
            try await Task.sleep(for: .milliseconds(300)) // the user is still dragging
            return screenshot
        }

        let first = Task { await model.capture() }
        try await Task.sleep(for: .milliseconds(50))
        #expect(model.isBusy)
        #expect(await model.capture() == nil) // ignored, not a second overlay
        #expect(await first.value != nil)
    }

    @Test func readsImageOnClipboard() async throws {
        defer { pasteboard.releaseGlobally() }
        let screenshot = try CodeImage.write(Self.code)
        defer { try? FileManager.default.removeItem(at: screenshot) }
        pasteboard.clearContents()
        pasteboard.setData(try Data(contentsOf: screenshot), forType: .png)
        let model = try makeModel { nil }

        let text = await model.readClipboard()

        #expect(indents(text) == Self.indents)
        #expect(pasteboard.string(forType: .string) == text) // the image is replaced by its text
    }

    @Test func clipboardWithoutImageSaysWhatToCopy() async throws {
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("just text", forType: .string)
        let model = try makeModel { nil }

        #expect(await model.readClipboard() == nil)
        guard case .failed(let message) = model.status else {
            Issue.record("expected a failure, got \(model.status)")
            return
        }
        #expect(message.lowercased().contains("no image"))
        #expect(pasteboard.string(forType: .string) == "just text")
    }

    @Test func linksRouteToActionsAndRejectUnknownOnes() async throws {
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("just text", forType: .string)
        let model = try makeModel { throw OverlayOpened() }

        await model.open(try #require(URL(string: "squint://clipboard?mode=plain")))
        guard case .failed(let clipboardMessage) = model.status else {
            Issue.record("expected a failure")
            return
        }
        #expect(clipboardMessage.lowercased().contains("no image")) // reached the clipboard action, not capture

        await model.open(try #require(URL(string: "squint://format-disk")))
        guard case .failed(let unknownMessage) = model.status else {
            Issue.record("expected a failure")
            return
        }
        #expect(unknownMessage.contains("Unknown link"))
    }

    /// Regression: menus can't wrap, and a long message stretched the menu across the screen.
    @Test func menuMessagesStayShort() async throws {
        let model = try makeModel { throw OverlayOpened() }
        let longLink = "squint://" + String(repeating: "very-long-path/", count: 20)

        await model.open(try #require(URL(string: longLink)))

        guard case .failed(let message) = model.status else {
            Issue.record("expected a failure, got \(model.status)")
            return
        }
        #expect(message.count <= CaptureModel.menuMessageLimit)
        #expect(message.hasSuffix("…"))
    }
}
