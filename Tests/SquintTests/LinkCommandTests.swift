import Foundation
import Testing
@testable import Squint

struct LinkCommandTests {
    private func command(_ link: String) throws -> LinkCommand? {
        LinkCommand(try #require(URL(string: link)))
    }

    @Test func parsesCommandsAndModes() throws {
        #expect(try command("squint://capture") == .capture(code: nil))
        #expect(try command("squint://capture?mode=code") == .capture(code: true))
        #expect(try command("squint://capture?mode=plain") == .capture(code: false))
        #expect(try command("SQUINT://Clipboard?mode=PLAIN") == .clipboard(code: false))
        #expect(try command("squint://clipboard?mode=other") == .clipboard(code: nil))
        #expect(try command("squint://settings") == .settings)
    }

    @Test func rejectsUnknownLinks() throws {
        #expect(try command("squint://delete-everything") == nil)
        #expect(try command("https://capture") == nil)
        #expect(try command("squint:") == nil)
    }
}
