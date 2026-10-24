import Foundation

/// The kind of code in a capture, judged from all its lines: repairs that only one language explains need to know it.
enum CodeLanguage: Equatable {
    case python
    /// JavaScript, TypeScript, Swift, Java, C and other languages that delimit blocks with braces.
    case braces
    case unknown

    static func detect(_ lines: [String]) -> CodeLanguage {
        var python = 0, braces = 0
        for line in lines {
            let text = line.trimmingCharacters(in: .whitespaces)
            if text.wholeMatch(of: /(async\s+)?(def|class|elif|except|with|for|while|if|else|try|finally)\b.*:/) != nil { python += 2 }
            if text.contains("self.") || text.hasPrefix("import ") || text.hasPrefix("from ") || text.hasPrefix("#") { python += 1 }
            if text.contains(/\b(None|True|False|elif|lambda)\b/) { python += 1 }
            if text.hasSuffix("{") || text.hasPrefix("}") || text.hasSuffix(";") || text.hasPrefix("//") { braces += 2 }
            // Strong even in a few lines, and before any repair (`{` is often misread).
            if text.contains(/=>|===|!==/) || text.firstMatch(of: /^(const|let|var|function|func|export)\b/) != nil { braces += 2 }
            if text.contains(/\b(null|undefined|this)\b/) { braces += 1 }
        }
        if python >= 2, python > braces { return .python }
        if braces >= 2, braces > python { return .braces }
        return .unknown
    }
}

/// Misreads that only one reading of code explains, fixed line by line.
enum CodeRepairs {
    /// Words before `(` that keep their space: keywords, and `function`'s name in styles that space it.
    private static let spacedBeforeParen: Set = [
        "if", "for", "while", "switch", "catch", "return", "function", "typeof", "await", "in", "of", "and", "or", "not",
        "elif", "with", "yield", "lambda", "assert", "else", "case", "throw", "new", "delete", "void", "import", "from",
        "is", "as", "do", "try", "async", "def", "class", "print", "exec", "raise", "except", "del", "global", "nonlocal",
    ]

    /// Cyrillic and Greek letters that Vision returns for Latin ones.
    private static let lookalikes: [Character: Character] = [
        "а": "a", "е": "e", "о": "o", "р": "p", "с": "c", "у": "y", "х": "x", "к": "k", "п": "n", "м": "m", "т": "t",
        "А": "A", "В": "B", "Е": "E", "К": "K", "М": "M", "Н": "H", "О": "O", "Р": "P", "С": "C", "Т": "T", "Х": "X",
        "І": "I", "і": "i", "ј": "j", "ѕ": "s", "ο": "o", "ν": "v",
    ]

    /// Only the parts of `line` outside strings and comments change: prose there has its own spacing and punctuation.
    static func repairing(_ line: String, language: CodeLanguage) -> String {
        outsideStringsAndComments(repairingQuotes(line, language: language), language: language) { repairingCode($0, language: language) }
    }

    /// A string compared or passed whose opening `'` Vision read as `i` or dropped (`=== ipeer'`, `=== workspace'`).
    /// Only on lines with an odd number of `'`, where a quote is surely missing.
    static func repairingQuotes(_ line: String, language: CodeLanguage) -> String {
        guard language != .unknown, line.count(where: { $0 == "'" }) % 2 == 1 else { return line }
        if let match = line.firstMatch(of: /(={2,3}|!={1,2})\s?i(\w[\w-]*)'/) {
            return line.replacingCharacters(in: match.range, with: "\(match.output.1) '\(match.output.2)'")
        }
        if let match = line.firstMatch(of: /(={2,3}|!={1,2})\s([A-Za-z][\w-]*)'/) {
            return line.replacingCharacters(in: match.range, with: "\(match.output.1) '\(match.output.2)'")
        }
        return line
    }

    private static func repairingCode(_ line: String, language: CodeLanguage) -> String {
        var line = line
        // Letters from other scripts inside an otherwise ASCII word (`пра` for `npa`), and `ø` for `0` and `‹` `›` for
        // `<` `>`, which code doesn't use.
        line = line.replacing(/[\p{L}\p{N}_]+/) { match in
            let word = match.output
            guard word.contains(where: { !$0.isASCII }), word.allSatisfy({ $0.isASCII || lookalikes[$0] != nil }) else { return String(word) }
            return String(word.map { lookalikes[$0] ?? $0 })
        }
        line = line.replacing(/(^|[^\p{L}])ø(?![\p{L}])/) { "\($0.output.1)0" }.replacing("‹", with: "<").replacing("›", with: ">")
        // No space between a function's name and its `(` (`readPasswords ()`), except after keywords and `function name`.
        // Simple word boundaries: Unicode's treat `log.warn` as one word.
        line = line.replacing(/(\b[A-Za-z_][\w]*)\s+\((?!\s)/.wordBoundaryKind(.simple)) { match in
            let name = String(match.output.1)
            let before = line[..<match.range.lowerBound].split(separator: " ").last.map(String.init)
            return spacedBeforeParen.contains(name) || before == "function" ? String(match.output.0) : name + "("
        }

        switch language {
        case .braces:
            line = line
                // `||` read as `Il`, `I1`, `ІI`, `|1` or `l|`, between spaces or at the end of the line.
                .replacing(/\ [Il1|]{2}(?=\ |$)/, with: " ||")
                // `=>` read as `>`: after a parameter list that follows `(`, `=`, `,` or `:`, or a lone name in a call.
                .replacing(/([(=,:]\s*|^\s*)(\([\w\s,{}\[\].]*\))\s>(?=\s|$)/) { "\($0.output.1)\($0.output.2) =>" }
                .replacing(/(\.\w+\(\s*\w+)\s>\s/) { "\($0.output.1) => " }
                // `({` read as `(t`, when the line closes the object it opens or a key follows.
                .replacing(/\(t\ (?=[^{}]*\ \}\)|\w+:\s)/, with: "({ ")
                // `{ name )` closing a destructuring pattern.
                .replacing(/\{\ ([\w,\ ]+)\ \)/) { "{ \($0.output.1) }" }
                // `x. y` in a member access.
                .replacing(/([\w)\]])\.\ ([a-z_]\w*)/) { "\($0.output.1).\($0.output.2)" }
            // `&` between conditions: `&&`, in lines that are clearly boolean.
            if line.contains(/^\s*(\}\s*)?(if|else if|while)\b|&&|\|\|/) {
                line = line.replacing(/([\w)])\ &\ (?=[\w!(])/) { "\($0.output.1) && " }
            }
            // `[` read as `I` in a line with more `]` than `[` (`forEach((Ik, v]) =>`).
            while line.count(where: { $0 == "]" }) > line.count(where: { $0 == "[" }),
                  let match = line.firstMatch(of: /([(,]\s?)I(?=\w)/) {
                line.replaceSubrange(match.range, with: "\(match.output.1)[")
            }
        case .python:
            // `def __name__(…):` read as `def__name__(…):`.
            line = line.replacing(/^(\s*)(def|class)(_\w*\(.*\)\s*:)$/) { "\($0.output.1)\($0.output.2) \($0.output.3)" }
                // `name_part` read as `name. _part`.
                .replacing(/(\w)\.\ _(\w)/) { "\($0.output.1)_\($0.output.2)" }
        case .unknown:
            break
        }
        return line
    }

    /// `line` with `transform` applied to each stretch of code between strings, and before a comment. An unclosed quote
    /// leaves the rest of the line alone.
    static func outsideStringsAndComments(_ line: String, language: CodeLanguage, _ transform: (String) -> String) -> String {
        var out = "", code = "", quote: Character?, escaped = false
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            if let open = quote {
                out.append(character)
                if escaped { escaped = false } else if character == "\\" { escaped = true } else if character == open { quote = nil }
            } else if "'\"`".contains(character) {
                out += transform(code) + String(character)
                code = ""
                quote = character
            } else if (language != .braces && character == "#") || (language != .python && line[index...].hasPrefix("//")) {
                return out + transform(code) + line[index...]
            } else {
                code.append(character)
            }
            index = line.index(after: index)
        }
        return out + transform(code)
    }

    /// A line Vision read where a lone docstring `"""` stands: two to four junk marks (`… … …`, `Л Н Н`, `1 11 3`).
    static func isMisreadDocstringQuote(_ line: String) -> Bool {
        let marks = line.filter { !$0.isWhitespace }
        guard (2...4).contains(marks.count), !marks.contains(where: { "=(){}[]:;".contains($0) }) else { return false }
        return marks.allSatisfy { !($0.isASCII && $0.isLetter && !"lI".contains($0)) && !("02456789".contains($0)) }
    }
}
