import Testing
@testable import Squint

/// Each repair is a misread seen on the benchmark's development set.
@Suite(.timeLimit(.minutes(1)))
struct CodeRepairsTests {
    @Test func detectsTheLanguage() {
        #expect(CodeLanguage.detect(["def f(self):", "    return None"]) == .python)
        #expect(CodeLanguage.detect(["const f = (x) => {", "  return x;", "}"]) == .braces)
        #expect(CodeLanguage.detect(["hello world"]) == .unknown)
    }

    @Test(arguments: [
        ("    return type === 'git' Il type === 'hosted'", "    return type === 'git' || type === 'hosted'"),
        ("    (keys.length === 1) ІI", "    (keys.length === 1) ||"),
        ("const isGitNode = (node) > {", "const isGitNode = (node) => {"),
        ("    .then((rUsername) > readUsername(msg, rUsername, true))", "    .then((rUsername) => readUsername(msg, rUsername, true))"),
        ("    const flags = customNames.filter(name > isFlag(name))", "    const flags = customNames.filter(name => isFlag(name))"),
        ("function showFields (t data, version, fields, json }) {", "function showFields ({ data, version, fields, json }) {"),
        ("    const { type ) = npa(node.resolved)", "    const { type } = npa(node.resolved)"),
        ("    return err. code", "    return err.code"),
        ("  if (isRetry & password) {", "  if (isRetry && password) {"),
        ("    return пра(spec)", "    return npa(spec)"),
        ("  if (customNames.length > ø) {", "  if (customNames.length > 0) {"),
        ("    return readPasswords ()", "    return readPasswords()"),
        ("    log.warn ('profile', 'Passwords do not match')", "    log.warn('profile', 'Passwords do not match')"),
        ("    : type === ipeer' ? chalk.magentaBright", "    : type === 'peer' ? chalk.magentaBright"),
        ("    : type === workspace' ? chalk.blueBright", "    : type === 'workspace' ? chalk.blueBright"),
        ("  return read(t prompt: msg, silent: true", "  return read({ prompt: msg, silent: true"),
        ("    Object.entries(s).forEach((Ik, v]) => {", "    Object.entries(s).forEach(([k, v]) => {"),
    ])
    func repairsBraceLanguageMisreads(_ read: String, _ code: String) {
        #expect(CodeRepairs.repairing(read, language: .braces) == code)
    }

    @Test(arguments: [
        ("def__floordiv__(self, other):", "def __floordiv__(self, other):"),
        ("        return 1 + day_of. _week - first_weekday", "        return 1 + day_of_week - first_weekday"),
        ("def destroy (self):", "def destroy(self):"),
        ("        if len(_iscoroutine_typecache) ‹ 100:", "        if len(_iscoroutine_typecache) < 100:"),
    ])
    func repairsPythonMisreads(_ read: String, _ code: String) {
        #expect(CodeRepairs.repairing(read, language: .python) == code)
    }

    @Test func leavesValidCodeStringsAndCommentsAlone() {
        for line in ["if (a > b) {", "x = a & mask", "return value", "print(f'{name}')"] {
            #expect(CodeRepairs.repairing(line, language: .braces) == line)
        }
        // Prose keeps its spacing: `be (partially)` in a comment, `e.g. this` in a string.
        #expect(CodeRepairs.repairing("        # because it will already be (partially) consumed.", language: .python)
            == "        # because it will already be (partially) consumed.")
        #expect(CodeRepairs.repairing("  log('see (below), e.g. this') // call (twice)", language: .braces)
            == "  log('see (below), e.g. this') // call (twice)")
        // Keywords, and a function's name in styles that space it, keep the space before `(`.
        #expect(CodeRepairs.repairing("  if (x) { return (y) }", language: .braces) == "  if (x) { return (y) }")
        #expect(CodeRepairs.repairing("function showFields ({ data }) {", language: .braces) == "function showFields ({ data }) {")
    }

    @Test func restoresBlockStructure() {
        // `} catch {` read as `catch` at the wrong indent; `=> {` read as `=>`; a closer lined up with its opener.
        let slots: [Slot] = [
            .text(indent: 0, "const safeNpa = (spec) =>"),
            .text(indent: 2, "try {"),
            .text(indent: 4, "return npa(spec)"),
            .text(indent: 4, "catch"),
            .text(indent: 4, "return null"),
            .ink(indent: 2),
            .ink(indent: 0),
        ]
        #expect(Recognizer.render(slots) == """
            const safeNpa = (spec) => {
              try {
                return npa(spec)
              } catch {
                return null
              }
            }
            """)
    }

    @Test func restoresCombinedClosersAndIgnoresBracketsInStrings() {
        // A callback's `})` that Vision skipped; the `(` and `{` in the string and comment don't count.
        let slots: [Slot] = [
            .text(indent: 0, "items.forEach((item) => {"),
            .text(indent: 2, "log('opening ({[ brackets') // and ( here"),
            .ink(indent: 0),
            .text(indent: 0, "run()"),
        ]
        #expect(Recognizer.render(slots) == "items.forEach((item) => {\n  log('opening ({[ brackets') // and ( here\n})\nrun()")
        // A line cut short before its `})` doesn't make the next brace close twice.
        #expect(CodeRepairs.code(of: "  return read({ prompt: 'a(b' ", language: .braces) == "  return read({ prompt:  ")
    }

    @Test func readsJunkWhereADocstringQuoteStands() {
        let slots: [Slot] = [
            .text(indent: 0, "def area(self):"),
            .text(indent: 4, "\"\"\"Return the area."),
            .text(indent: 4, "… … …"),
            .text(indent: 4, "return self.w * self.h"),
        ]
        #expect(Recognizer.render(slots) == "def area(self):\n    \"\"\"Return the area.\n    \"\"\"\n    return self.w * self.h")
        #expect(!CodeRepairs.isMisreadDocstringQuote("x = 1"))
    }
}

@Suite(.timeLimit(.minutes(1)))
struct MarkdownFenceTests {
    @Test(arguments: [
        ("guard let x = y else { return }", "swift"),
        ("fn main() {\n    let mut x = 1;\n}", "rust"),
        ("package main\n\nfunc main() {\n    x := 1\n}", "go"),
        ("const f = (x) => x * 2", "javascript"),
        ("def f(self):\n    return self.x", "python"),
        ("SELECT name FROM users", "sql"),
    ])
    func tagsTheLanguage(_ code: String, _ tag: String) {
        #expect(MarkdownFence.tag(for: code) == tag)
    }

    @Test func fencesSafely() {
        #expect(MarkdownFence.tag(for: "hello world") == nil)
        #expect(MarkdownFence.wrapping("hello") == "```\nhello\n```")
        // Code with its own ``` gets a longer fence.
        #expect(MarkdownFence.wrapping("let s = \"```\"").hasPrefix("````"))
    }
}
