import AppKit
import Carbon.HIToolbox
import Foundation
import SwiftUI
import Testing
@testable import Squint

struct ShortcutTests {
    private func keyDown(_ characters: String, keyCode: Int, flags: NSEvent.ModifierFlags) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                                      context: nil, characters: characters, charactersIgnoringModifiers: characters,
                                      isARepeat: false, keyCode: UInt16(keyCode)))
    }

    @Test func standardShortcutDisplaysInAppleOrder() {
        #expect(Shortcut.standard.displayName == "⇧⌘2")
        #expect(Shortcut.standard.keyboardShortcut == KeyboardShortcut("2", modifiers: [.shift, .command]))
    }

    @Test func recordsKeyPressWithModifiers() throws {
        let shortcut = Shortcut(event: try keyDown("s", keyCode: kVK_ANSI_S, flags: [.command, .option]))
        #expect(shortcut == Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | optionKey), key: "S"))
        #expect(shortcut?.displayName == "⌥⌘S")
    }

    @Test func rejectsKeysWithoutCommandOptionOrControl() throws {
        #expect(Shortcut(event: try keyDown("s", keyCode: kVK_ANSI_S, flags: [])) == nil)
        #expect(Shortcut(event: try keyDown("S", keyCode: kVK_ANSI_S, flags: [.shift])) == nil)
    }

    @Test func namesSpecialKeys() throws {
        let shortcut = Shortcut(event: try keyDown(" ", keyCode: kVK_Space, flags: [.control]))
        #expect(shortcut?.displayName == "⌃Space")
        #expect(shortcut?.keyboardShortcut == nil) // menus can't show it, so no key equivalent
    }

    @Test func survivesEncoding() throws {
        let data = try JSONEncoder().encode(Shortcut.standard)
        #expect(try JSONDecoder().decode(Shortcut.self, from: data) == .standard)
    }
}
