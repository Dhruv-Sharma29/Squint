import CoreImage.CIFilterBuiltins
import Foundation
import Testing
@testable import Squint

// Three minutes: unoptimized test builds compare screenshots with every emoji slowly, CI's machines slower still.
@Suite(.timeLimit(.minutes(3)))
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

    @Test func repairsCodeOnlyMisreads() {
        #expect(Recognizer.repairingCodeMisreads("log('Found ${count} files')") == "log(`Found ${count} files`)")
        #expect(Recognizer.repairingCodeMisreads("const s = 'cost: $5'") == "const s = 'cost: $5'") // no ${ }: a plain string
        #expect(Recognizer.repairingCodeMisreads("default: password |l ''") == "default: password || ''")
        #expect(Recognizer.repairingCodeMisreads("a l| b") == "a || b")
        // Without a real `|`, "Il" could be an identifier, as here, so it is never touched.
        #expect(Recognizer.repairingCodeMisreads("const Il = 1") == "const Il = 1")
    }

    @Test func restoresBracesMisreadAsOtherGlyphs() {
        let slots: [Slot] = [
            .text(indent: 0, "if (isRetry) f"), // `{` read as `f`
            .text(indent: 2, "return password"),
            .text(indent: 0, "8"), // lone `}` read as `8`
        ]
        #expect(Recognizer.render(slots) == "if (isRetry) {\n  return password\n}")
        // A lone `)` closing a multi-line call is left alone.
        #expect(Recognizer.render([.text(indent: 0, "call("), .text(indent: 2, "x"), .text(indent: 0, ")")]) == "call(\n  x\n)")
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

    /// Regression from the dev set: Vision read only 3 of 11 line numbers, and the gutter was kept.
    @Test func removesGutterWhenMostNumbersAreUnread() {
        let rows: [[TextBox]] = (0..<11).map { line in
            let code = box("code \(line)", row: line, x: 0.12 + (line % 3 == 1 ? 0.04 : 0), width: 0.3)
            return [1, 10, 11].contains(line + 1) ? [box("\(line + 1)", row: line, x: line + 1 >= 10 ? 0.02 : 0.04, width: line + 1 >= 10 ? 0.04 : 0.02), code] : [code]
        }
        let (code, gutterEnd) = Recognizer.removingLineNumbers(rows)
        #expect(code.allSatisfy { $0.count == 1 && $0[0].text.hasPrefix("code") })
        #expect(abs(gutterEnd - 0.06) < 0.0001)
    }

    /// Regression from blurry 1080p frames: one row's number was misread and merged with its code, and that single row
    /// used to veto removing the whole gutter.
    @Test func removesGutterDespiteAMergedMisreadNumber() {
        var rows: [[TextBox]] = (0..<10).map { line in
            [box("\(line + 1)", row: line, x: line + 1 >= 10 ? 0.02 : 0.04, width: line + 1 >= 10 ? 0.04 : 0.02),
             box("code \(line)", row: line, x: 0.12, width: 0.3)]
        }
        rows[3] = [box("4O  code 3", row: 3, x: 0.04, width: 0.38)] // "4" misread as "4O" and merged
        let (code, gutterEnd) = Recognizer.removingLineNumbers(rows)
        #expect(gutterEnd > 0)
        #expect(code.map { $0.map(\.text) } == (0..<10).map { ["code \($0)"] })
    }

    @Test func keepsNumbersThatStartAtTheCodeMargin() {
        let rows: [[TextBox]] = [
            [box("1", row: 0, x: 0.10, width: 0.02), box("+ offset", row: 0, x: 0.14, width: 0.2)],
            [box("2", row: 1, x: 0.10, width: 0.02), box("* scale", row: 1, x: 0.14, width: 0.2)],
            [box("total()", row: 2, x: 0.10, width: 0.2)], // code starts where the numbers are
        ]
        #expect(Recognizer.removingLineNumbers(rows).gutterEnd == 0)
    }

    @Test func keepsCodeThatMerelyStartsWithNumbers() {
        let decreasing: [[TextBox]] = (0..<4).map { [box("\(3 - $0)", row: $0, x: 0.1, width: 0.02), box("+ x", row: $0, x: 0.14, width: 0.1)] }
        #expect(Recognizer.removingLineNumbers(decreasing).gutterEnd == 0)
        let notAligned: [[TextBox]] = (0..<4).map { [box("\($0 + 1)", row: $0, x: 0.1 + Double($0) * 0.08, width: 0.02)] }
        #expect(Recognizer.removingLineNumbers(notAligned).gutterEnd == 0)
        let fewNumbers: [[TextBox]] = [[box("1", row: 0, x: 0.1, width: 0.02)]] + (1..<6).map { [box("code", row: $0, x: 0.1, width: 0.2)] }
        #expect(Recognizer.removingLineNumbers(fewNumbers).rows.count == 6)
    }

    @Test func readsQRCode() async throws {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("https://example.com/squint".utf8)
        let qr = try #require(filter.outputImage?.transformed(by: .init(scaleX: 10, y: 10)))
        let url = URL.temporaryDirectory.appending(path: "squint-test-qr.png")
        try CIContext().writePNGRepresentation(of: qr, to: url, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try await Recognizer.text(at: url, code: true) == "https://example.com/squint")
    }

    /// Vision blocks its calling thread while its own work runs on Swift's thread pool. Before recognition moved to
    /// its own queue, as many images at once as the pool has threads deadlocked; on a three-core CI runner, three did.
    @Test func recognizesMoreImagesAtOnceThanThePoolHasThreads() async throws {
        let url = try CodeImage.write("let answer = 42")
        defer { try? FileManager.default.removeItem(at: url) }
        let count = ProcessInfo.processInfo.activeProcessorCount + 2
        let texts = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<count {
                group.addTask { try await Recognizer.text(at: url, code: true) }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        #expect(texts == Array(repeating: "let answer = 42", count: count))
    }

    /// Vision can't read emoji: it skips them or reads `:`, and can drop the text after one, such as the `")` here.
    @Test func keepsEmojiInCode() async throws {
        let code = "let cat = \"🐱\"\n// 🚀 ship it\nprint(\"done ✅\")\n🚀Launch day\nx=🚀+1"
        let url = try CodeImage.write(code)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try await Recognizer.text(at: url, code: true) == code)
    }

    @Test func readsALineOfOnlyEmoji() async throws {
        let url = try CodeImage.write("🚀 🎉 🐛")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try await Recognizer.text(at: url, code: true) == "🚀 🎉 🐛")
    }

    /// Benchmark screenshots that, during development, came back with emoji that aren't there: a blurred blue `n` read as
    /// 👖, and syntax-highlighted keywords and brackets in a video frame read as 🌑 and 🇸🇦 dozens of times.
    @Test(arguments: ["py-16", "js-17"])
    func findsNoEmojiInCodeWithout(_ name: String) async throws {
        let fixture = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/\(name).png")
        let text = try await Recognizer.text(at: fixture, code: true)
        #expect(!text.unicodeScalars.contains { $0.properties.isEmojiPresentation })
    }

    @Test func customWordsFixOneLetterMisreads() {
        let words = ["Flaxmere", "yaml", "UIKit", "go"]
        #expect(Recognizer.applyingCustomWords("Open Flaxmers with flaxmere.yami", words: words) == "Open Flaxmere with flaxmere.yaml")
        #expect(Recognizer.applyingCustomWords("import UlKit", words: words) == "import UIKit")
        // One letter off is fixed; two letters off, and words under four letters, are left alone.
        #expect(Recognizer.applyingCustomWords("Flaxmore Flexmors gg do", words: words) == "Flaxmere Flexmors gg do")
        #expect(Recognizer.applyingCustomWords("Flaxmers", words: []) == "Flaxmers")
    }

    @Test func reportsMissingAndUnreadableFilesDistinctly() async throws {
        let missing = URL.temporaryDirectory.appending(path: "squint-missing-\(UUID().uuidString).png")
        let missingError = await #expect(throws: CocoaError.self) { try await Recognizer.text(at: missing, code: true) }
        #expect(missingError?.code == .fileReadNoSuchFile)

        let notAnImage = URL.temporaryDirectory.appending(path: "squint-text-\(UUID().uuidString).png")
        try Data("not an image".utf8).write(to: notAnImage)
        defer { try? FileManager.default.removeItem(at: notAnImage) }
        let formatError = await #expect(throws: CocoaError.self) { try await Recognizer.text(at: notAnImage, code: true) }
        #expect(formatError?.code == .fileReadCorruptFile)
    }

    @Test func metrics() {
        #expect(Metrics.distance("kitten", "sitting") == 3)
        #expect(Metrics.exactLines("a\nb\nc", truth: "a\nx\nc") == 2.0 / 3.0)
    }
}
