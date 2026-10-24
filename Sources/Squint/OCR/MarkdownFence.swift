import Foundation

/// Copy as Markdown: code in a fenced block with a language tag, ready for a README, a chat or an AI prompt.
enum MarkdownFence {
    static func wrapping(_ code: String) -> String {
        // The fence is longer than any run of backticks in the code, as CommonMark requires.
        let longest = code.matches(of: /`+/).map { $0.output.count }.max() ?? 0
        let fence = String(repeating: "`", count: max(3, longest + 1))
        return fence + (tag(for: code) ?? "") + "\n" + code + "\n" + fence
    }

    /// The language, from what's distinctive to each; nil when unsure, since no tag beats a wrong one.
    static func tag(for code: String) -> String? {
        let checks: [(String, Regex<Substring>)] = [
            ("swift", /\b(?:guard let|func \w+\(.*\)\s*->|import (?:SwiftUI|Foundation|UIKit)|@State|@MainActor)\b|\bvar \w+:\s*[A-Z]/),
            ("rust", /\bfn \w+\(|\blet mut\b|\bimpl\b.*\{|println!\(/),
            ("go", /^package \w+|\bfunc \w+\(.*\)\s*\w*\s*\{|:=/.anchorsMatchLineEndings()),
            ("typescript", /\binterface \w+\s*\{|:\s*(?:string|number|boolean)\b|\bimport type\b/),
            ("javascript", /=>|===|!==|\b(?:const|let|var) \w+ =|\bfunction\b|\brequire\(|console\.log/),
            ("python", /^\s*(?:def|class) \w+.*:\s*$|^\s*(?:import|from) \w+|\bself\.|\belif\b/.anchorsMatchLineEndings()),
            ("java", /\bpublic (?:static )?(?:class|void|int|String)\b|System\.out\./),
            ("cpp", /#include\s*<|std::|\bcout\b/),
            ("sql", /^\s*(?:SELECT|INSERT|UPDATE|DELETE|CREATE TABLE)\b/.anchorsMatchLineEndings().ignoresCase()),
            ("sh", /^\s*(?:\$ |sudo |brew |npm |git |cd |export \w+=)/.anchorsMatchLineEndings()),
        ]
        return checks.first { code.contains($0.1) }?.0
    }
}
