import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Capture Table: Vision's document recognition (macOS 26 and later) reads tables with or without ruled lines, and
/// Squint copies them as Markdown or as tab-separated values for a spreadsheet.
enum TableReader {
    enum Format: String, CaseIterable, Sendable {
        case markdown, tsv
    }

    /// Whether this Mac can read tables.
    static var isAvailable: Bool {
        #if compiler(>=6.2) // the macOS 26 SDK, which has document recognition
        if #available(macOS 26, *) { return true }
        #endif
        return false
    }

    /// The largest table in the image, as rows of cells, or nil if there's none (or this Mac can't read tables).
    static func table(at url: URL) async throws -> [[String]]? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: url.path(percentEncoded: false)])
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url.path(percentEncoded: false)]) }
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            let tables = try await RecognizeDocumentsRequest().perform(on: image).flatMap { $0.document.tables }
            let largest = tables.max { $0.rows.count * ($0.rows.first?.count ?? 0) < $1.rows.count * ($1.rows.first?.count ?? 0) }
            return largest.map { $0.rows.map { $0.map { $0.content.text.transcript } } }
        }
        #endif
        return nil
    }

    static func formatted(_ rows: [[String]], as format: Format) -> String {
        let width = rows.map(\.count).max() ?? 0
        // Every row as wide as the widest; a cell's own line breaks become spaces.
        let cells = rows.map { row in (row + Array(repeating: "", count: width - row.count)).map { $0.replacing(/\s*\n\s*/, with: " ") } }
        switch format {
        case .tsv:
            return cells.map { $0.map { $0.replacing("\t", with: " ") }.joined(separator: "\t") }.joined(separator: "\n")
        case .markdown:
            guard let header = cells.first else { return "" }
            func line(_ row: [String]) -> String { "| " + row.map { $0.replacing("|", with: "\\|") }.joined(separator: " | ") + " |" }
            return ([line(header), "|" + String(repeating: " --- |", count: width)] + cells.dropFirst().map(line)).joined(separator: "\n")
        }
    }
}
