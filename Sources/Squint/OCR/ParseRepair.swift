import Foundation
import JavaScriptCore

/// Repair guided by parsing: when Code Mode's output doesn't parse, try fixes for the misreads that break parsing, on
/// the line the parser blames and the one before it, and keep the result only if the whole snippet then parses.
/// Otherwise the output stays as it was, so this can turn broken code into valid code but never valid code into broken.
/// JavaScript is checked in-process by JavaScriptCore; Python by `python3 -m ast` when a Python is installed.
enum ParseRepair {
    enum Verdict: Equatable {
        case parses
        /// The 1-based line the parser stopped at.
        case fails(line: Int)
    }

    static func repairing(_ text: String, language: CodeLanguage) -> String {
        guard let check = checker(for: language), case .fails(var line) = check([text])[0] else { return text }
        var current = text
        for _ in 0..<8 {
            let lines = current.components(separatedBy: "\n")
            // The first candidate that parses, or else the first that moves the error further down.
            let candidates = candidates(lines, near: line, language: language)
            let verdicts = check(candidates)
            if let fixed = zip(candidates, verdicts).first(where: { $0.1 == .parses }) { return fixed.0 }
            guard let progress = zip(candidates, verdicts).first(where: { if case .fails(let next) = $0.1 { next > line } else { false } }),
                  case .fails(let next) = progress.1
            else { return text }
            (current, line) = (progress.0, next)
        }
        return text
    }

    // MARK: - Fixes

    /// Whole-snippet candidates, each fixing one line near `line` (1-based) in one way.
    static func candidates(_ lines: [String], near line: Int, language: CodeLanguage) -> [String] {
        var out: [String] = []
        func with(_ index: Int, _ replacement: String) {
            guard lines.indices.contains(index), lines[index] != replacement else { return }
            var copy = lines
            copy[index] = replacement
            out.append(copy.joined(separator: "\n"))
        }
        for index in [line - 1, line - 2] where lines.indices.contains(index) {
            let text = lines[index]
            // A string Vision cut off: close it and the brackets opened on the line.
            for quote in ["'", "\"", "`"] where text.count(where: { String($0) == quote }) % 2 == 1 {
                with(index, text + quote + closers(for: text))
            }
            // Characters code doesn't contain, such as `•` or `…`.
            let ascii = text.filter { $0.isASCII }
            if ascii != text { with(index, ascii) }
            // A closer with nothing to close: drop it, or the opener left without one: close it.
            if let last = text.last, ")]}".contains(last) { with(index, String(text.dropLast())) }
            if !closers(for: text).isEmpty { with(index, text + closers(for: text)) }
            // A string's opening quote read as `i` (`getattr(cls,i_module_', None)`, `(no I1 ino-')`).
            if let match = text.firstMatch(of: /([(,=\s])\s?i([\w-]+)(['"])/), text.count(where: { String($0) == match.output.3 }) % 2 == 1 {
                with(index, text.replacingCharacters(in: match.range, with: "\(match.output.1) \(match.output.3)\(match.output.2)\(match.output.3)"))
            }
            // A bracket of the wrong type (`{self!r]`, `(})`): each bracket as each other type, trying first those that leave
            // the line's brackets matched (inside an f-string, `(self!r]` parses too).
            let kinds: [Character: String] = ["(": "[{", "[": "({", "{": "([", ")": "]}", "]": ")}", "}": ")]"]
            // Closers before openers: the opener as read is usually right (`{self!r]` is `{self!r}`, not `[self!r]`).
            let positions = text.indices.filter { ")]}".contains(text[$0]) } + text.indices.filter { "([{".contains(text[$0]) }
            let swaps = positions.flatMap { offset in
                kinds[text[offset]]!.map { text.replacingCharacters(in: offset...offset, with: String($0)) }
            }
            for swap in swaps.filter(matched) + swaps.filter({ !matched($0) }) { with(index, swap) }
            if language == .braces, text.wholeMatch(of: /\s*[A-Za-z][\w,.']*(\s+[\w,.']+){2,}\s*/) != nil {
                // A comment whose `//` Vision dropped: prose where code should be.
                let indent = text.prefix { $0 == " " }
                with(index, String(indent) + "// " + String(text.dropFirst(indent.count)))
            }
            if language == .python {
                // `.` read as a space between a name or `)` and a call (`self.buffer append(x)`, `super() seekable()`).
                if let match = text.firstMatch(of: /([\w)])\s+([A-Za-z_]\w*)\(/),
                   !["return", "not", "in", "and", "or", "is", "await", "if", "elif", "while", "for", "assert", "yield", "del", "def", "class", "print", "raise", "lambda", "import", "from", "as", "with", "except"].contains(String(text[..<match.range.lowerBound].split(whereSeparator: { !$0.isLetter && $0 != "_" }).last ?? "")) || match.output.1 == ")" {
                    with(index, text.replacingCharacters(in: match.range, with: "\(match.output.1).\(match.output.2)("))
                }
                // `()` read as `Q`, `0` or `O` in a definition (`def resumeQ:`).
                if let match = text.firstMatch(of: /^(\s*def\s+\w+?)[QO0]:\s*$/) { with(index, String(match.output.1) + "():") }
                // A docstring's `"""` read as another mix of quotes (`'''"`).
                if let quotes = text.firstMatch(of: /^(\s*)['"]{3,4}/) { with(index, String(quotes.output.1) + "\"\"\"" + String(text[quotes.range.upperBound...])) }
                if let quotes = text.firstMatch(of: /['"]{3,4}$/) { with(index, String(text[..<quotes.range.lowerBound]) + "\"\"\"") }
                // A block statement without its `:`.
                if text.firstMatch(of: /^\s*(def|class|if|elif|else|for|while|with|try|except|finally)\b[^:]*$/) != nil { with(index, text + ":") }
            }
        }
        // Parsers often stop far below a cut-off string, so closing one is tried on every line. Nothing that isn't on
        // screen is added, such as closers for a capture that ends mid-function: those would make partial code parse.
        for index in lines.indices where index != line - 1 && index != line - 2 {
            for quote in ["'", "\""] where lines[index].count(where: { String($0) == quote }) % 2 == 1 {
                with(index, lines[index] + quote + closers(for: lines[index]))
            }
        }
        // Python docstrings: every `"""` misread as another mix of quotes, fixed together (one alone never parses), and a
        // docstring opened by a lone `"` right after a `def` or `class`.
        if language == .python {
            var fixed = lines
            for i in fixed.indices {
                fixed[i] = fixed[i].replacing(/^(\s*)['"]{3,4}(?=\S|$)/) { "\($0.output.1)\"\"\"" }
                    .replacing(/(\S)['"]{3,4}$/) { "\($0.output.1)\"\"\"" }
                if i > 0, fixed[i - 1].firstMatch(of: /^\s*(async\s+)?(def|class)\b.*:\s*$/) != nil,
                   let lone = fixed[i].firstMatch(of: /^(\s*)"\s?(?=\w)/) {
                    fixed[i].replaceSubrange(lone.range, with: String(lone.output.1) + "\"\"\"")
                }
            }
            if fixed != lines { out.append(fixed.joined(separator: "\n")) }
        }
        // Every line shifted right by the first one's indent (`unexpected indent` on line 1).
        if language == .python, line == 1, let indent = lines.first?.prefix(while: { $0 == " " }).count, indent > 0 {
            out.append(lines.map { $0.hasPrefix(String(repeating: " ", count: indent)) ? String($0.dropFirst(indent)) : $0 }.joined(separator: "\n"))
        }
        return out
    }

    /// Whether every bracket in `line` closes the one it should.
    private static func matched(_ line: String) -> Bool {
        let pairs: [Character: Character] = ["(": ")", "[": "]", "{": "}"]
        var open: [Character] = []
        for character in line {
            if pairs[character] != nil { open.append(character) } else if ")]}".contains(character) {
                guard let top = open.popLast(), pairs[top] == character else { return false }
            }
        }
        return open.isEmpty
    }

    /// Closers for the brackets `line` opens and doesn't close, innermost first.
    private static func closers(for line: String) -> String {
        let pairs: [Character: Character] = ["(": ")", "[": "]", "{": "}"]
        var open: [Character] = []
        for character in line {
            if pairs[character] != nil { open.append(character) } else if let top = open.last, pairs[top] == character { open.removeLast() }
        }
        return String(open.reversed().compactMap { pairs[$0] })
    }

    // MARK: - Checking

    /// Checks several snippets at once: Python's are sent to one process, which is most of the cost.
    static func checker(for language: CodeLanguage) -> (([String]) -> [Verdict])? {
        switch language {
        case .braces: { $0.map(javaScript) }
        case .python: python.map { interpreter in { check($0, with: interpreter) } }
        case .unknown: nil
        }
    }

    /// Checked both as a script and as a function body, since snippets are often a function's insides (`return`).
    private static func javaScript(_ code: String) -> Verdict {
        guard let context = JSGlobalContextCreate(nil) else { return .parses }
        defer { JSGlobalContextRelease(context) }
        func syntax(_ source: String, startingAt line: Int32) -> Int? {
            let script = JSStringCreateWithCFString(source as CFString)
            defer { JSStringRelease(script) }
            var exception: JSValueRef?
            if JSCheckScriptSyntax(context, script, nil, line, &exception) { return nil }
            guard let exception, let object = JSValueToObject(context, exception, nil) else { return 1 }
            let name = JSStringCreateWithCFString("line" as CFString)
            defer { JSStringRelease(name) }
            return Int(JSValueToNumber(context, JSObjectGetProperty(context, object, name, nil), nil))
        }
        guard let asScript = syntax(code, startingAt: 1) else { return .parses }
        guard let asBody = syntax("(async function () {\n" + code + "\n})", startingAt: 0) else { return .parses }
        return .fails(line: max(asScript, asBody))
    }

    /// An installed Python, never `/usr/bin/python3`: without the developer tools, that stub asks to install them.
    static let python: URL? = [
        "/opt/homebrew/bin/python3", "/usr/local/bin/python3",
        "/Library/Developer/CommandLineTools/usr/bin/python3",
        "/Applications/Xcode.app/Contents/Developer/usr/bin/python3",
    ].map { URL(filePath: $0) }.first { FileManager.default.isExecutableFile(atPath: $0.path(percentEncoded: false)) }

    /// One `python3` for all of `codes`: it prints, per snippet, 0 if it parses or the line where it stops.
    private static func check(_ codes: [String], with interpreter: URL) -> [Verdict] {
        guard !codes.isEmpty, let json = try? JSONEncoder().encode(codes) else { return [] }
        let process = Process()
        process.executableURL = interpreter
        process.arguments = ["-I", "-c", """
            import ast, json, sys
            for code in json.load(sys.stdin):
                try:
                    ast.parse(code)
                    print(0)
                except (SyntaxError, ValueError) as e:
                    print(getattr(e, "lineno", None) or 1)
            """]
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        // Without a working Python, nothing is changed.
        guard (try? process.run()) != nil else { return codes.map { _ in .parses } }
        input.fileHandleForWriting.write(json)
        try? input.fileHandleForWriting.close()
        let reply = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        let lines = reply.split(separator: "\n").compactMap { Int($0) }
        guard lines.count == codes.count else { return codes.map { _ in .parses } }
        return lines.map { $0 == 0 ? .parses : .fails(line: $0) }
    }
}
