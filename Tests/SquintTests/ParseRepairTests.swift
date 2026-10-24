import Testing
@testable import Squint

/// Repair guided by parsing turns broken code into valid code, or leaves it alone.
@Suite(.timeLimit(.minutes(1)))
struct ParseRepairTests {
    @Test func closesAStringVisionCutOff() {
        let read = "const go = async () => {\n  const pw = await ask('New password:\n  return pw\n}"
        #expect(ParseRepair.repairing(read, language: .braces) == "const go = async () => {\n  const pw = await ask('New password:')\n  return pw\n}")
    }

    @Test func fixesAWrongBracketTypeKeepingTheOpener() {
        let read = "const f = (x) => {\n  return g(x]\n}"
        #expect(ParseRepair.repairing(read, language: .braces) == "const f = (x) => {\n  return g(x)\n}")
    }

    @Test(.enabled(if: ParseRepair.python != nil, "needs an installed Python"))
    func repairsPythonThatOnlyOneReadingParses() {
        // `.` read as a space, `()` read as `Q`, and both of a docstring's `"""` misread.
        #expect(ParseRepair.repairing("def f(self):\n    self.buffer append(1)", language: .python) == "def f(self):\n    self.buffer.append(1)")
        #expect(ParseRepair.repairing("def resumeQ:\n    pass", language: .python) == "def resume():\n    pass")
        #expect(ParseRepair.repairing("def f():\n    '''\"Doc.\n    More.\"'\"\n    return 1", language: .python)
            == "def f():\n    \"\"\"Doc.\n    More.\"\"\"\n    return 1")
    }

    @Test func leavesValidAndUnfixableCodeAlone() {
        let valid = "const f = (x) => {\n  return x * 2\n}"
        #expect(ParseRepair.repairing(valid, language: .braces) == valid)
        let hopeless = "= = = (\n} ] ) {{\n@@@"
        #expect(ParseRepair.repairing(hopeless, language: .braces) == hopeless)
        #expect(ParseRepair.repairing("anything ((", language: .unknown) == "anything ((")
    }
}
