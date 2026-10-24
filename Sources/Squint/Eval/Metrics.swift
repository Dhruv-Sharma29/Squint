/// Scores OCR output against hand-typed ground truth.
enum Metrics {
    /// Levenshtein distance over characters.
    static func distance(_ a: String, _ b: String) -> Int {
        let b = Array(b)
        var row = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var diagonal = row[0]
            row[0] = i + 1
            for (j, cb) in b.enumerated() {
                let above = row[j + 1]
                row[j + 1] = min(row[j] + 1, above + 1, diagonal + (ca == cb ? 0 : 1))
                diagonal = above
            }
        }
        return row[b.count]
    }

    /// Character error rate: edits needed per ground-truth character.
    static func cer(_ output: String, truth: String) -> Double {
        Double(distance(output, truth)) / Double(max(truth.count, 1))
    }

    /// Share of lines that match exactly, position by position. Indentation counts.
    static func exactLines(_ output: String, truth: String) -> Double {
        let o = output.split(separator: "\n", omittingEmptySubsequences: false)
        let t = truth.split(separator: "\n", omittingEmptySubsequences: false)
        return Double(zip(o, t).count { $0 == $1 }) / Double(max(o.count, t.count))
    }
}
