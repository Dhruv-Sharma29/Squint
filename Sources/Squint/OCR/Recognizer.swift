import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Apple Vision OCR plus a code-aware layout pass. Vision drops leading whitespace,
/// blank lines and lone closing brackets, and code needs all three.
enum Recognizer {
    private struct Box {
        let text: String
        let rect: CGRect
    }

    static func text(at url: URL, code: Bool) throws -> String {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url.path(percentEncoded: false)]) }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = !code // English autocorrect mangles identifiers and symbols
        request.automaticallyDetectsLanguage = !code // helps prose in other languages; code is mostly ASCII
        let barcodes = VNDetectBarcodesRequest()
        try VNImageRequestHandler(cgImage: image).perform([request, barcodes])

        // ponytail: a QR code or barcode in the selection wins over its text; mixed selections lose the text.
        let payloads = (barcodes.results ?? []).compactMap(\.payloadStringValue)
        if !payloads.isEmpty { return payloads.joined(separator: "\n") }

        let boxes = (request.results ?? []).compactMap { observation -> Box? in
            guard let text = observation.topCandidates(1).first?.string, !text.isEmpty else { return nil }
            return Box(text: text, rect: observation.boundingBox)
        }

        let rows = group(boxes)
        guard code else { return rows.map { $0.map(\.text).joined(separator: " ") }.joined(separator: "\n") }
        return render(slots(rows, ink: InkMap(image)))
    }

    /// Left edges -> indent columns, snapped to the smallest indent step seen.
    // ponytail: assumes monospace + one indent unit; continuation lines aligned to "(" get snapped. Revisit when eval shows it.
    static func indents(_ lefts: [Double], charWidth: Double) -> [Int] {
        guard let base = lefts.min(), charWidth > 0 else { return lefts.map { _ in 0 } }
        let columns = lefts.map { Int((($0 - base) / charWidth).rounded()) }
        let unit = columns.filter { $0 > 0 }.min() ?? 1
        return columns.map { Int((Double($0) / Double(unit)).rounded()) * unit }
    }

    /// Slots -> text. Repairs `{` misread as `1`/`I`/`l`/`|` before an indented block, and fills
    /// rows Vision skipped with the closer for the innermost open bracket.
    // ponytail: bracket counting ignores strings/comments and emits bare `}` (not `});`). Use a tokenizer once eval data shows it matters.
    static func render(_ slots: [Slot]) -> String {
        let pairs: [Character: Character] = ["{": "}", "(": ")", "[": "]"]
        var open: [Character] = []
        var lines: [String] = []
        for (index, slot) in slots.enumerated() {
            switch slot {
            case .blank:
                lines.append("")
            case .ink(let indent):
                let closer = open.popLast().flatMap { pairs[$0] }
                lines.append(closer.map { String(repeating: " ", count: indent) + String($0) } ?? "")
            case .text(let indent, var text):
                if let next = slots[(index + 1)...].lazy.compactMap(\.indent).first, next > indent,
                   let last = text.last, "1Il|".contains(last), text.dropLast().hasSuffix(" ") {
                    text = text.dropLast() + "{"
                }
                for character in text {
                    if pairs[character] != nil {
                        open.append(character)
                    } else if let top = open.last, pairs[top] == character {
                        open.removeLast()
                    }
                }
                lines.append(String(repeating: " ", count: indent) + text)
            }
        }
        while lines.last?.isEmpty == true { lines.removeLast() }
        return lines.joined(separator: "\n")
    }

    /// Groups boxes into visual rows, top to bottom (Vision's origin is bottom-left).
    private static func group(_ boxes: [Box]) -> [[Box]] {
        var rows: [[Box]] = []
        for box in boxes.sorted(by: { $0.rect.midY > $1.rect.midY }) {
            if let first = rows.last?.first, abs(first.rect.midY - box.rect.midY) < min(first.rect.height, box.rect.height) / 2 {
                rows[rows.count - 1].append(box)
            } else {
                rows.append([box])
            }
        }
        return rows.map { $0.sorted { $0.rect.minX < $1.rect.minX } }
    }

    /// Lays rows on a line grid: gaps become blank rows, or `.ink` rows when pixels show a glyph Vision skipped.
    private static func slots(_ rows: [[Box]], ink: InkMap?) -> [Slot] {
        let all = rows.flatMap { $0 }
        let long = all.filter { $0.text.count >= 4 }
        let charWidth = median((long.isEmpty ? all : long).map { $0.rect.width / Double($0.text.count) })
        let mids = rows.map { Double($0[0].rect.midY) }
        let pitch = median(zip(mids, mids.dropFirst()).map { $0 - $1 })
        let band = median(all.map { Double($0.rect.height) }) * 0.4

        // left == nil means an empty row; text == nil with a left edge means unread ink.
        var items: [(text: String?, left: Double?)] = []
        for (index, row) in rows.enumerated() {
            if index > 0, pitch > 0 {
                let missing = max(0, Int(((mids[index - 1] - mids[index]) / pitch).rounded()) - 1)
                for step in 0..<missing {
                    items.append((nil, ink?.leftEdge(midY: mids[index - 1] - Double(step + 1) * pitch, halfHeight: band)))
                }
            }
            items.append((join(row, charWidth: charWidth), row[0].rect.minX))
        }
        // Closing brackets after the last recognized row.
        if pitch > 0, var y = mids.last.map({ $0 - pitch }) {
            while y - band > 0, let left = ink?.leftEdge(midY: y, halfHeight: band) {
                items.append((nil, left))
                y -= pitch
            }
        }

        var columns = indents(items.compactMap(\.left), charWidth: charWidth).makeIterator()
        return items.map { item in
            guard item.left != nil, let indent = columns.next() else { return .blank }
            return item.text.map { .text(indent: indent, $0) } ?? .ink(indent: indent)
        }
    }

    /// Joins boxes on one row, keeping the original column gaps.
    private static func join(_ row: [Box], charWidth: Double) -> String {
        var line = row[0].text
        for (left, right) in zip(row, row.dropFirst()) {
            let gap = charWidth > 0 ? Int(((right.rect.minX - left.rect.maxX) / charWidth).rounded()) : 1
            line += String(repeating: " ", count: max(1, gap)) + right.text
        }
        return line
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted.isEmpty ? 0 : sorted[sorted.count / 2]
    }
}
