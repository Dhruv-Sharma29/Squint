import CoreImage.CIFilterBuiltins
import Foundation
import Testing
@testable import Squint

struct RecognizerTests {
    @Test func indentsSnapToSmallestStep() {
        let charWidth = 0.01
        let lefts = [0.1, 0.1 + 4 * charWidth * 1.05, 0.1 + 8 * charWidth * 0.96, 0.1]
        #expect(Recognizer.indents(lefts, charWidth: charWidth) == [0, 4, 8, 0])
        #expect(Recognizer.indents([], charWidth: charWidth) == [])
    }

    @Test func renderRepairsBracesVisionMissed() {
        let slots: [Slot] = [
            .text(indent: 0, "function f() {"),
            .text(indent: 2, "for (x of a) 1"), // `{` misread as `1`
            .text(indent: 4, "g(x);"),
            .ink(indent: 2), // lone `}` Vision skipped
            .blank,
            .text(indent: 2, "return 1;"),
            .ink(indent: 0),
            .ink(indent: 0), // stray ink with nothing left open
        ]
        #expect(Recognizer.render(slots) == "function f() {\n  for (x of a) {\n    g(x);\n  }\n\n  return 1;\n}")
    }

    @Test func renderLeavesPythonAlone() {
        let slots: [Slot] = [.text(indent: 0, "if x == 1:"), .text(indent: 4, "y = 1")]
        #expect(Recognizer.render(slots) == "if x == 1:\n    y = 1")
    }

    @Test func readsQRCode() throws {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("https://example.com/squint".utf8)
        let qr = try #require(filter.outputImage?.transformed(by: .init(scaleX: 10, y: 10)))
        let url = URL.temporaryDirectory.appending(path: "squint-test-qr.png")
        try CIContext().writePNGRepresentation(of: qr, to: url, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try Recognizer.text(at: url, code: true) == "https://example.com/squint")
    }

    @Test func metrics() {
        #expect(Metrics.distance("kitten", "sitting") == 3)
        #expect(Metrics.exactLines("a\nb\nc", truth: "a\nx\nc") == 2.0 / 3.0)
    }
}
