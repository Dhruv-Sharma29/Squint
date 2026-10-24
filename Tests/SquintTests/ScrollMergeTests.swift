import Testing
@testable import Squint

@Suite(.timeLimit(.minutes(1)))
struct ScrollMergeTests {
    @Test func joinsCapturesByTheLinesTheyShare() {
        let first = "def f(x):\n    a = 1\n    b = 2\n    c = 3"
        let second = "    b = 2\n    c = 3\n    d = 4\n    return d"
        #expect(ScrollMerge.merging(first, second) == "def f(x):\n    a = 1\n    b = 2\n    c = 3\n    d = 4\n    return d")
    }

    @Test func shiftsTheNewPartToAgreeOnIndentation() {
        // The second capture starts inside the body, so its own indentation starts at 0.
        let first = "def f(x):\n    if x:\n        a = 1"
        let second = "    a = 1\nb = 2\nreturn b"
        #expect(ScrollMerge.merging(first, second) == "def f(x):\n    if x:\n        a = 1\n    b = 2\n    return b")
    }

    @Test func toleratesSpacingAndOneMisreadInALongOverlap() {
        let first = "a = 1\nb = 2\nc = 3\nd = 4\ne = 5"
        let second = "b =2\nc = 8\nd = 4\ne = 5\nf = 6"
        #expect(ScrollMerge.merging(first, second) == first + "\nf = 6")
    }

    @Test func appendsWhenNothingIsShared() {
        #expect(ScrollMerge.merging("a = 1", "b = 2") == "a = 1\nb = 2")
        #expect(ScrollMerge.merging("", "b = 2") == "b = 2")
        // Shared blank lines alone aren't an overlap.
        #expect(ScrollMerge.merging("a = 1\n", "\nb = 2") == "a = 1\n\n\nb = 2")
    }
}
