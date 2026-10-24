import AppKit
import Foundation
import Testing
@testable import Squint

@Suite(.timeLimit(.minutes(1)))
struct TableReaderTests {
    private let rows = [["Name", "Stars"], ["Squint", "128"], ["a|b", "multi\nline"]]

    @Test func formatsMarkdownAndTabSeparated() {
        #expect(TableReader.formatted(rows, as: .markdown) == "| Name | Stars |\n| --- | --- |\n| Squint | 128 |\n| a\\|b | multi line |")
        #expect(TableReader.formatted(rows, as: .tsv) == "Name\tStars\nSquint\t128\na|b\tmulti line")
        // Short rows are padded to the widest.
        #expect(TableReader.formatted([["a", "b"], ["c"]], as: .tsv) == "a\tb\nc\t")
    }

    @Test(.enabled(if: TableReader.isAvailable, "needs macOS 26 or later"))
    @MainActor func capturesATableWithoutRuledLines() async throws {
        let url = try Self.renderTable([["Name", "Language"], ["Squint", "Swift"], ["Vision", "Objective-C"]])
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("squint-table-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let defaults = try #require(UserDefaults(suiteName: "squint-table-\(UUID().uuidString)"))
        let model = CaptureModel(preferences: Preferences(defaults: defaults), pasteboard: pasteboard,
                                 screenAccess: { true }, captureRegion: { url }, registersHotKey: false)
        let table = await model.captureTable()
        #expect(table == "| Name | Language |\n| --- | --- |\n| Squint | Swift |\n| Vision | Objective-C |")
        #expect(pasteboard.string(forType: .string) == table)
    }

    /// A table drawn as aligned columns on white, with no lines.
    static func renderTable(_ rows: [[String]]) throws -> URL {
        let column = 170.0, rowHeight = 34.0
        let width = column * Double(rows[0].count) + 40, height = rowHeight * Double(rows.count) + 40
        let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * 2), pixelsHigh: Int(height * 2),
                                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        rep.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        for (r, row) in rows.enumerated() {
            for (c, cell) in row.enumerated() {
                let font = r == 0 ? NSFont.boldSystemFont(ofSize: 15) : NSFont.systemFont(ofSize: 15)
                NSAttributedString(string: cell, attributes: [.font: font, .foregroundColor: NSColor.black])
                    .draw(at: NSPoint(x: 20 + column * Double(c), y: height - 20 - rowHeight * Double(r + 1) + 9))
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        let url = URL.temporaryDirectory.appending(path: "squint-table-\(UUID().uuidString).png")
        try #require(rep.representation(using: .png, properties: [:])).write(to: url)
        return url
    }
}
