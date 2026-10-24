import CoreGraphics
import Foundation

/// Runs of spaces inside a line, which Vision collapses to one (two spaces before an aligned comment, after a full stop
/// in a docstring). In monospaced code a space is one character cell, so the blank gap between glyphs says how many
/// spaces there are. Vision's character boxes cover whole words, so they can't say.
enum Spacing {
    /// `text` with each run of spaces as wide as the gap in the pixels. The gaps are matched to the runs in order, and
    /// only when there are as many of each; otherwise `text` is returned as it is.
    /// - Parameters: rect: the text's box, normalized with the origin bottom-left; charWidth: normalized.
    static func restoringRuns(_ text: String, rect: CGRect, ink: InkMap, charWidth: Double) -> String {
        let runs = text.trimmingCharacters(in: .whitespaces).matches(of: /\ +/)
        guard !runs.isEmpty, charWidth > 0 else { return text }
        let w = Double(ink.width), h = Double(ink.height)
        let cell = charWidth * w
        let left = max(0, Int(rect.minX * w)), right = min(ink.width, Int(rect.maxX * w))
        let top = max(0, Int((1 - rect.maxY) * h)), bottom = min(ink.height, Int((1 - rect.minY) * h))
        guard right - left > 2, bottom > top, cell >= 3 else { return text }
        let bg = ink.background
        func inked(_ x: Int) -> Bool {
            for y in top..<bottom {
                let i = (y * ink.width + x) * 4
                let r = abs(Int(ink.pixels[i]) - bg.0), g = abs(Int(ink.pixels[i + 1]) - bg.1), b = abs(Int(ink.pixels[i + 2]) - bg.2)
                if r + g + b > 90 { return true }
            }
            return false
        }
        let columns = (left..<right).map(inked)
        guard let first = columns.firstIndex(of: true), let last = columns.lastIndex(of: true) else { return text }
        // Blank stretches between glyphs at least three quarters of a cell wide: letter spacing is narrower.
        var gaps: [Int] = [], blank = 0
        for column in columns[first...last] {
            if column {
                if Double(blank) >= 0.75 * cell { gaps.append(max(1, Int(Double(blank) / cell))) }
                blank = 0
            } else {
                blank += 1
            }
        }
        guard gaps.count == runs.count else { return text }
        let leading = text.prefix { $0 == " " }, body = text.dropFirst(leading.count)
        var gapsLeft = gaps[...]
        return String(leading) + body.replacing(/\ +/) { _ in String(repeating: " ", count: gapsLeft.popFirst() ?? 1) }
    }
}
