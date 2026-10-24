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
