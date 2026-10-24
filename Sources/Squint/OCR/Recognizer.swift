import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Apple Vision OCR plus a code-aware layout pass. Vision drops leading whitespace,
/// blank lines and lone closing brackets, and code needs all three.
enum Recognizer {
    /// Vision language codes this Mac can recognize, for the Plain Mode language setting.
    static let supportedLanguages: [String] = (try? VNRecognizeTextRequest().supportedRecognitionLanguages()) ?? []

    /// Vision's `perform` blocks its thread while Vision's own work runs on Swift's cooperative thread pool. Called from
    /// that pool with as many images at once as it has threads (one per core: three on a CI runner), every thread
    /// blocks and nothing is left to run Vision's work. So images are recognized one at a time on this queue, and
    /// callers wait without holding a pool thread.
    private static let vision = DispatchQueue(label: "Squint.Recognizer", qos: .userInitiated)

    /// - Parameter language: Plain Mode only; a Vision language code, or nil to detect the language automatically.
    static func text(at url: URL, code: Bool, language: String? = nil) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            vision.async { continuation.resume(with: Result { try recognize(url, code: code, language: language) }) }
        }
    }

    private static func recognize(_ url: URL, code: Bool, language: String?) throws -> String {
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

    /// Removes an editor's line-number gutter: at least two right-aligned, increasing integers at the far left, with all
    /// the code starting clearly to their right. Vision often skips lone digits, so most rows may have no readable number;
    /// the empty column is the stronger evidence. Returns the remaining rows and the gutter's right edge (0 without a
    /// gutter), so ink is only searched to its right.
    static func removingLineNumbers(_ rows: [[TextBox]]) -> (rows: [[TextBox]], gutterEnd: Double) {
        let numbered = rows.compactMap { row in row.first.flatMap { Int($0.text) }.map { (value: $0, box: row[0]) } }
        let increasing = zip(numbered, numbered.dropFirst()).count { $0.value < $1.value }
        let height = median(rows.flatMap { $0 }.map { Double($0.rect.height) })
        let ends = numbered.map { Double($0.box.rect.maxX) }
        guard numbered.count >= 2, Double(increasing) >= 0.8 * Double(numbered.count - 1),
              let gutterEnd = ends.max(), let first = ends.min(), gutterEnd - first < height // right-aligned column
        else { return (rows, 0) }

        // A row's leading box inside the gutter: a line number, or one Vision misread (such as "l7"). A misread number
        // Vision merged with the code ("lO  return x") is cut off the front of the box.
        func inGutter(_ box: TextBox) -> Bool { Double(box.rect.maxX) <= gutterEnd + height / 2 && box.text.count <= 4 }
        let code = rows.map { row -> [TextBox] in
            guard let lead = row.first else { return row }
            if inGutter(lead) { return Array(row.dropFirst()) }
            if Double(lead.rect.minX) < gutterEnd, let rest = droppingMergedNumber(lead) { return [rest] + row.dropFirst() }
            return row
        }
        // The code must start clearly right of the gutter. If more than a few rows start at the number column, the
        // numbers are part of the code (a few may be misreads Vision merged beyond recognition).
        let atMargin = code.count { row in row.first.map { Double($0.rect.minX) - gutterEnd <= height / 2 } ?? false }
        guard Double(atMargin) <= 0.2 * Double(code.count) else { return (rows, 0) }
        return (code.filter { !$0.isEmpty }, gutterEnd)
    }

    /// The box without a leading line-number-like token ("12", "l7", "1O") and the spaces after it. Its new left edge
    /// assumes monospaced text.
    private static func droppingMergedNumber(_ box: TextBox) -> TextBox? {
        guard let match = box.text.firstMatch(of: /^[0-9lIOSB]{1,4}\s+(?=\S)/), match.0.contains(where: \.isNumber) else { return nil }
        let fraction = Double(box.text.distance(from: box.text.startIndex, to: match.range.upperBound)) / Double(box.text.count)
        let rect = CGRect(x: box.rect.minX + box.rect.width * fraction, y: box.rect.minY,
                          width: box.rect.width * (1 - fraction), height: box.rect.height)
        return TextBox(text: String(box.text[match.range.upperBound...]), rect: rect)
    }

    /// Vision sometimes merges a line number with the code after it ("12  return x"). Split it off, using the
    /// candidate's own character geometry, so gutter detection sees it. Without a gutter the pieces rejoin as before.
    // Measured dead end: splitting every word this way to rebuild spacing from on-screen gaps raised the dev-set
    // character error rate from 4.1% to 12.5%; Vision's word boxes in accurate mode are too approximate for that.
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
                   let last = text.last, "1Il|ft".contains(last), text.dropLast().hasSuffix(" ") {
                    text = text.dropLast() + "{"
                }
                // A lone `}` misread as `8`, `)` or `]` while the innermost open bracket is a brace.
                if open.last == "{", ["8", ")", "]"].contains(text) {
                    text = "}"
                }
                text = repairingCodeMisreads(repairingSquareBrackets(text))
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

    /// Misreads that only one reading of code explains:
    /// - a string quoted with `'` that contains `${` is a template literal, whose backticks Vision reads as `'`;
    /// - `|l`, `l|`, `|I` or `I|` between spaces is `||`.
    static func repairingCodeMisreads(_ line: String) -> String {
        line.replacing(/'([^'`]*\$\{[^'`]*)'/) { "`\($0.1)`" }
            .replacing(/\ (?:\|[lI]|[lI]\|)\ /, with: " || ")
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
