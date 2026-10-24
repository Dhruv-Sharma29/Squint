import Foundation

/// Scroll capture: joins the text of a capture taken after scrolling to the text so far, by the lines they share.
enum ScrollMerge {
    /// `next` added after `previous`, without the lines both show. The overlap is the longest run where the end of
    /// `previous` matches the start of `next`, comparing lines without whitespace (Vision spaces the same line
    /// differently from capture to capture). Lines one or two characters apart count as the same, and overlaps of four
    /// or more may have one that isn't. Where they differ on `previous`'s last line, `next`'s version wins: that line had
    /// nothing below it to confirm, for example, that a trailing `1` is a block's `{`. Each capture measures indentation from its
    /// own leftmost line, so `next` is shifted to agree with `previous`. With no overlap, `next` follows as it is.
    static func merging(_ previous: String, _ next: String) -> String {
        guard !previous.isEmpty else { return next }
        let old = previous.components(separatedBy: "\n"), new = next.components(separatedBy: "\n")
        func key(_ line: String) -> String { line.filter { !$0.isWhitespace } }
        func similar(_ a: String, _ b: String) -> Bool {
            key(a) == key(b) || Metrics.distance(key(a), key(b)) <= max(1, key(a).count / 10)
        }
        for overlap in stride(from: min(old.count, new.count), through: 1, by: -1) {
            let pairs = Array(zip(old.suffix(overlap), new.prefix(overlap)))
            let unlike = pairs.count { !similar($0, $1) }
            // Blank lines alone match anything: an overlap needs a line of text both read the same, or, if every line
            // differs slightly, enough text to be sure of.
            let exact = pairs.contains { !key($0).isEmpty && key($0) == key($1) }
            let text = pairs.filter { similar($0, $1) }.map { key($0.0).count }.reduce(0, +)
            guard unlike <= (overlap >= 4 ? 1 : 0), exact || text >= 8 else { continue }
            let shifts = pairs.filter { !key($0.0).isEmpty && similar($0.0, $0.1) }.map { indent($0.0) - indent($0.1) }
            let shift = mostCommon(shifts) ?? 0
            var kept = Array(old.dropLast(overlap) + pairs.map(\.0))
            if let last = pairs.last, key(last.0) != key(last.1) { kept[kept.count - 1] = shifted(last.1, by: shift) }
            return (kept + new.dropFirst(overlap).map { shifted($0, by: shift) }).joined(separator: "\n")
        }
        return previous + "\n" + next
    }

    private static func indent(_ line: String) -> Int { line.prefix { $0 == " " }.count }

    private static func shifted(_ line: String, by shift: Int) -> String {
        guard !line.isEmpty else { return line }
        return shift >= 0 ? String(repeating: " ", count: shift) + line : String(line.dropFirst(min(-shift, indent(line))))
    }

    private static func mostCommon(_ values: [Int]) -> Int? {
        Dictionary(grouping: values, by: { $0 }).max { $0.value.count < $1.value.count }?.key
    }
}
