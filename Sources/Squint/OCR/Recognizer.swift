import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Apple Vision OCR plus a code-aware layout pass. Vision drops leading whitespace,
/// blank lines and lone closing brackets, and code needs all three.
enum Recognizer {
    /// Vision language codes this Mac can recognize, for the Plain Mode language setting.
    static let supportedLanguages: [String] = (try? VNRecognizeTextRequest().supportedRecognitionLanguages()) ?? []

    /// - Parameter language: Plain Mode only; a Vision language code, or nil to detect the language automatically.
    static func text(at url: URL, code: Bool, language: String? = nil) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: url.path(percentEncoded: false)])
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url.path(percentEncoded: false)]) }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = !code // English autocorrect mangles identifiers and symbols
        if !code, let language {
            request.recognitionLanguages = [language]
        } else {
            request.automaticallyDetectsLanguage = !code // helps prose in other languages; code is mostly ASCII
        }
        let barcodes = VNDetectBarcodesRequest()
        try VNImageRequestHandler(cgImage: image).perform([request, barcodes])

        // ponytail: a QR code or barcode in the selection wins over its text; mixed selections lose the text.
        let payloads = (barcodes.results ?? []).compactMap(\.payloadStringValue)
        if !payloads.isEmpty { return payloads.joined(separator: "\n") }

        let boxes = (request.results ?? []).flatMap { observation -> [TextBox] in
            guard let candidate = observation.topCandidates(1).first, !candidate.string.isEmpty else { return [] }
            return splittingLeadingNumber(candidate, rect: observation.boundingBox)
        }

        let rows = group(boxes)
        guard code else { return rows.map { $0.map(\.text).joined(separator: " ") }.joined(separator: "\n") }
        // Line spacing comes from every row, line numbers included: once the gutter is removed, rows that held only a
        // number are gone, and spacing measured from what's left would double and hide the gaps.
        let pitch = linePitch(rows)
        let (codeRows, gutterEnd) = removingLineNumbers(rows)
        return render(slots(codeRows, ink: InkMap(image), scanFrom: gutterEnd, pitch: pitch))
    }

    /// Removes an editor's line-number gutter: a left column of right-aligned, mostly increasing integers.
    /// Returns the remaining rows and the gutter's right edge (0 without a gutter), so ink is only searched to its right.
    static func removingLineNumbers(_ rows: [[TextBox]]) -> (rows: [[TextBox]], gutterEnd: Double) {
        let numbered = rows.compactMap { row in row.first.flatMap { Int($0.text) }.map { (value: $0, box: row[0]) } }
        let increasing = zip(numbered, numbered.dropFirst()).count { $0.value < $1.value }
        let height = median(rows.flatMap { $0 }.map { Double($0.rect.height) })
        let ends = numbered.map { Double($0.box.rect.maxX) }
        guard numbered.count >= 3, Double(numbered.count) >= 0.5 * Double(rows.count),
              Double(increasing) >= 0.8 * Double(numbered.count - 1),
              let gutterEnd = ends.max(), let first = ends.min(), gutterEnd - first < height // right-aligned column
        else { return (rows, 0) }

        // Drop each row's leading box inside the gutter, including numbers Vision misread (such as "l7").
        let code = rows.map { row in
            guard let lead = row.first, Double(lead.rect.maxX) <= gutterEnd + height / 2, lead.text.count <= 4 else { return row }
            return Array(row.dropFirst())
        }
        return (code.filter { !$0.isEmpty }, gutterEnd)
    }

    /// Vision sometimes merges a line number with the code after it ("12  return x"). Split it off, using the
    /// candidate's own character geometry, so gutter detection sees it. Without a gutter the pieces rejoin as before.
    private static func splittingLeadingNumber(_ candidate: VNRecognizedText, rect: CGRect) -> [TextBox] {
        let text = candidate.string
        guard let match = text.firstMatch(of: /^(\d{1,4})\s+(?=\S)/),
              let numberRect = try? candidate.boundingBox(for: text.startIndex..<match.1.endIndex)?.boundingBox,
              let restRect = try? candidate.boundingBox(for: match.range.upperBound..<text.endIndex)?.boundingBox
        else { return [TextBox(text: text, rect: rect)] }
        return [TextBox(text: String(match.1), rect: numberRect), TextBox(text: String(text[match.range.upperBound...]), rect: restRect)]
    }

    /// Left edges -> indent columns, snapped to the smallest indent step seen.
    // ponytail: assumes monospace + one indent unit; continuation lines aligned to "(" get snapped. Revisit when eval shows it.
    static func indents(_ lefts: [Double], charWidth: Double) -> [Int] {
        guard let base = lefts.min(), charWidth > 0 else { return lefts.map { _ in 0 } }
        let columns = lefts.map { Int((($0 - base) / charWidth).rounded()) }
        let unit = columns.filter { $0 > 0 }.min() ?? 1
        return columns.map { Int((Double($0) / Double(unit)).rounded()) * unit }
    }

    /// Slots -> text. Repairs `{` misread as `1`/`I`/`l`/`|` before an indented block, and fills rows Vision
    /// skipped: with the closer for the innermost open bracket, or with a Python docstring's lone `"""`.
    // ponytail: bracket counting ignores strings/comments and emits bare `}` (not `});`). Use a tokenizer once eval data shows it matters.
    static func render(_ slots: [Slot]) -> String {
        let pairs: [Character: Character] = ["{": "}", "(": ")", "[": "]"]
        var open: [Character] = []
        var lines: [String] = []
        var inDocstring = false
        var previousText: String?
        for (index, slot) in slots.enumerated() {
            switch slot {
            case .blank:
                lines.append("")
            case .ink(let indent):
                let padding = String(repeating: " ", count: indent)
                let opensDocstring = open.isEmpty && previousText?.wholeMatch(of: /\s*(async\s+)?(def|class)\b.*:\s*/) != nil
                if inDocstring || opensDocstring {
                    lines.append(padding + "\"\"\"")
                    inDocstring.toggle()
                } else {
                    let closer = open.popLast().flatMap { pairs[$0] }
                    lines.append(closer.map { padding + String($0) } ?? "")
                }
            case .text(let indent, var text):
                if let next = slots[(index + 1)...].lazy.compactMap(\.indent).first, next > indent,
                   let last = text.last, "1Il|".contains(last), text.dropLast().hasSuffix(" ") {
                    text = text.dropLast() + "{"
                }
                text = repairingSquareBrackets(text)
                var floor = open.count
                for character in text {
                    if pairs[character] != nil {
                        open.append(character)
                    } else if let top = open.last, pairs[top] == character {
                        open.removeLast()
                        floor = min(floor, open.count)
                    }
                }
                // A `(` or `[` left open mid-line is most likely a misread closer. Keep `{` and a trailing
                // opener (a multi-line call or literal), so one misread can't change which closers get restored.
                let trailing = text.last { !$0.isWhitespace }
                let opened = open[floor...]
                open.removeSubrange(floor...)
                open += opened.enumerated().filter { offset, opener in
                    opener == "{" || (offset == opened.count - 1 && opener == trailing)
                }.map(\.element)
                if text.ranges(of: "\"\"\"").count % 2 == 1 {
                    inDocstring.toggle()
                }
                previousText = text
                lines.append(String(repeating: " ", count: indent) + text)
            }
        }
        while lines.last?.isEmpty == true { lines.removeLast() }
        return lines.joined(separator: "\n")
    }

    /// Vision often reads `]` as `l`. While a line has more `[` than `]`, `[name` followed by `l` and then
    /// `;`, `.`, `)`, `,`, a space or the line end becomes `[name]`.
    static func repairingSquareBrackets(_ line: String) -> String {
        var line = line
        while line.count(where: { $0 == "[" }) > line.count(where: { $0 == "]" }),
              let match = line.firstMatch(of: /\[(\w*?)l(?=[;.),\s]|$)/) {
            line.replaceSubrange(match.range, with: "[\(match.1)]")
        }
        return line
    }

    /// Groups boxes into visual rows, top to bottom (Vision's origin is bottom-left).
    private static func group(_ boxes: [TextBox]) -> [[TextBox]] {
        var rows: [[TextBox]] = []
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
    /// The distance between consecutive lines: the median gap between rows.
    private static func linePitch(_ rows: [[TextBox]]) -> Double {
        let mids = rows.map { Double($0[0].rect.midY) }
        return median(zip(mids, mids.dropFirst()).map { $0 - $1 })
    }

    private static func slots(_ rows: [[TextBox]], ink: InkMap?, scanFrom: Double, pitch: Double) -> [Slot] {
        let all = rows.flatMap { $0 }
        let long = all.filter { $0.text.count >= 4 }
        let charWidth = median((long.isEmpty ? all : long).map { $0.rect.width / Double($0.text.count) })
        let mids = rows.map { Double($0[0].rect.midY) }
        let band = median(all.map { Double($0.rect.height) }) * 0.4

        // left == nil means an empty row; text == nil with a left edge means unread ink.
        var items: [(text: String?, left: Double?)] = []
        for (index, row) in rows.enumerated() {
            if index > 0, pitch > 0 {
                let missing = max(0, Int(((mids[index - 1] - mids[index]) / pitch).rounded()) - 1)
                for step in 0..<missing {
                    items.append((nil, ink?.leftEdge(midY: mids[index - 1] - Double(step + 1) * pitch, halfHeight: band, from: scanFrom)))
                }
            }
            items.append((join(row, charWidth: charWidth), row[0].rect.minX))
        }
        // Closing brackets after the last recognized row.
        if pitch > 0, var y = mids.last.map({ $0 - pitch }) {
            while y - band > 0, let left = ink?.leftEdge(midY: y, halfHeight: band, from: scanFrom) {
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
    private static func join(_ row: [TextBox], charWidth: Double) -> String {
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
