import AppKit
import Foundation
import Testing
@testable import Squint

/// Plain Mode with automatic detection, for someone who also reads Hindi.
@Suite(.timeLimit(.minutes(1)))
struct LanguageTests {
    @Test(.enabled(if: Recognizer.supportedLanguages.contains("hi-IN"), "Vision reads Hindi on newer macOS only"))
    func readsAnotherPreferredLanguageWhenDetectionIsUnsure() async throws {
        // Detection picks English for a line that's mostly English words and drops the Devanagari.
        let mixed = try Self.render("आज का standup cancel है।", size: 14)
        defer { try? FileManager.default.removeItem(at: mixed) }
        #expect(try await Recognizer.text(at: mixed, code: false, alsoTry: "hi-IN") == "आज का standup cancel है।")
        // Hindi in Latin letters stays in Latin letters: detection is confident there.
        let hinglish = try Self.render("Kal ki meeting postpone ho gayi.", size: 14)
        defer { try? FileManager.default.removeItem(at: hinglish) }
        #expect(try await Recognizer.text(at: hinglish, code: false, alsoTry: "hi-IN") == "Kal ki meeting postpone ho gayi.")
    }

    /// Black on white in the system font, as `bench/hindi/Render.swift` draws the benchmark.
    static func render(_ text: String, size: Double) throws -> URL {
        let string = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: NSColor.black])
        let bounds = string.size()
        let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(bounds.width + 40), pixelsHigh: Int(bounds.height + 30),
                                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh).fill()
        string.draw(at: NSPoint(x: 20, y: 15))
        NSGraphicsContext.restoreGraphicsState()
        let url = URL.temporaryDirectory.appending(path: "squint-language-\(UUID().uuidString).png")
        try #require(rep.representation(using: .png, properties: [:])).write(to: url)
        return url
    }
}
