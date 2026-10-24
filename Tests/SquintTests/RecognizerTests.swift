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

    @Test func repairsSquareBracketReadAsL() {
        #expect(Recognizer.repairingSquareBrackets("const k = item[keyl;") == "const k = item[key];")
        #expect(Recognizer.repairingSquareBrackets("groups[kl.push(item);") == "groups[k].push(item);")
        #expect(Recognizer.repairingSquareBrackets("const label = cells[col];") == "const label = cells[col];")
    }

    @Test func misreadOpenerDoesNotChangeRestoredClosers() {
        // Real Vision output: `]` read as `l` used to leave `[` open, so lone `}` lines came back as `]`.
        let slots: [Slot] = [
            .text(indent: 0, "for (const x of xs) {"),
            .text(indent: 2, "const k = x[keyl;"),
            .text(indent: 2, "if (k) {"),
            .text(indent: 4, "use(k);"),
            .ink(indent: 2),
            .ink(indent: 0),
        ]
        #expect(Recognizer.render(slots) == "for (const x of xs) {\n  const k = x[key];\n  if (k) {\n    use(k);\n  }\n}")
    }

    @Test func restoresLoneDocstringQuotes() {
        let slots: [Slot] = [
            .text(indent: 0, "def create_lock(self):"),
            .ink(indent: 4), // lone opening """ Vision skipped
            .text(indent: 4, "Acquire a lock."),
            .ink(indent: 4), // lone closing """
            .text(indent: 4, "return Lock()"),
        ]
        #expect(Recognizer.render(slots) == "def create_lock(self):\n    \"\"\"\n    Acquire a lock.\n    \"\"\"\n    return Lock()")
    }

    @Test func multiLineLiteralStillCloses() {
        let slots: [Slot] = [.text(indent: 0, "const xs = ["), .text(indent: 2, "1,"), .ink(indent: 0)]
        #expect(Recognizer.render(slots) == "const xs = [\n  1,\n]")
    }

    @Test func renderLeavesPythonAlone() {
        let slots: [Slot] = [.text(indent: 0, "if x == 1:"), .text(indent: 4, "y = 1")]
        #expect(Recognizer.render(slots) == "if x == 1:\n    y = 1")
    }

    /// A box on row `row` (top = 0) from `x` to `x + width`, in Vision's normalized, bottom-left coordinates.
    private func box(_ text: String, row: Int, x: Double, width: Double) -> TextBox {
        TextBox(text: text, rect: CGRect(x: x, y: 0.9 - Double(row) * 0.06, width: width, height: 0.04))
    }

    @Test func removesLineNumberGutter() {
        let rows: [[TextBox]] = [
            [box("1", row: 0, x: 0.03, width: 0.02), box("def f(x):", row: 0, x: 0.10, width: 0.3)],
            [box("2", row: 1, x: 0.03, width: 0.02), box("if x:", row: 1, x: 0.14, width: 0.2)],
            [box("3", row: 2, x: 0.03, width: 0.02)], // blank code line: only its number
            [box("l4", row: 3, x: 0.01, width: 0.04), box("return 1", row: 3, x: 0.18, width: 0.3)], // misread "14"
            [box("15", row: 4, x: 0.01, width: 0.04), box("return 0", row: 4, x: 0.14, width: 0.3)],
        ]
        let (code, gutterEnd) = Recognizer.removingLineNumbers(rows)
        #expect(code.map { $0.map(\.text) } == [["def f(x):"], ["if x:"], ["return 1"], ["return 0"]])
        #expect(abs(gutterEnd - 0.05) < 0.0001)
    }

    @Test func keepsCodeThatMerelyStartsWithNumbers() {
        let decreasing: [[TextBox]] = (0..<4).map { [box("\(3 - $0)", row: $0, x: 0.1, width: 0.02), box("+ x", row: $0, x: 0.14, width: 0.1)] }
        #expect(Recognizer.removingLineNumbers(decreasing).gutterEnd == 0)
        let notAligned: [[TextBox]] = (0..<4).map { [box("\($0 + 1)", row: $0, x: 0.1 + Double($0) * 0.08, width: 0.02)] }
        #expect(Recognizer.removingLineNumbers(notAligned).gutterEnd == 0)
        let fewNumbers: [[TextBox]] = [[box("1", row: 0, x: 0.1, width: 0.02)]] + (1..<6).map { [box("code", row: $0, x: 0.1, width: 0.2)] }
        #expect(Recognizer.removingLineNumbers(fewNumbers).rows.count == 6)
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
