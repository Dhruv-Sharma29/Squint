import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A global keyboard shortcut, stored as the Carbon key code and modifier mask that `RegisterEventHotKey` expects.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    /// The key as shown to people, such as "2", "S" or "Space".
    var key: String

    static let standard = Shortcut(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(cmdKey | shiftKey), key: "2")

    private static let namedKeys: [Int: String] = [
        kVK_Space: "Space", kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    /// The shortcut for a recorded key press. Nil unless it includes ⌘, ⌥ or ⌃, so ordinary typing can't trigger a capture.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.isDisjoint(with: [.command, .option, .control]) else { return nil }
        let key: String
        if let name = Self.namedKeys[Int(event.keyCode)] {
            key = name
        } else if let character = event.characters(byApplyingModifiers: [])?.uppercased(), character.count == 1,
                  character.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && !CharacterSet.whitespaces.contains($0) }) {
            key = character
        } else {
            return nil
        }
        var modifiers = 0
        if flags.contains(.control) { modifiers |= controlKey }
        if flags.contains(.option) { modifiers |= optionKey }
        if flags.contains(.shift) { modifiers |= shiftKey }
        if flags.contains(.command) { modifiers |= cmdKey }
        self.init(keyCode: UInt32(event.keyCode), modifiers: UInt32(modifiers), key: key)
    }

    /// In Apple's standard order: ⌃⌥⇧⌘ then the key.
    var displayName: String {
        let symbols = [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
            .filter { modifiers & UInt32($0.0) != 0 }
            .map(\.1)
            .joined()
        return symbols + key
    }

    /// Shown beside the menu item; nil for keys a menu can't display, such as F-keys.
    var keyboardShortcut: KeyboardShortcut? {
        guard key.count == 1, let character = key.lowercased().first else { return nil }
        var eventModifiers: SwiftUI.EventModifiers = [] // qualified: Carbon has an EventModifiers type too
        if modifiers & UInt32(controlKey) != 0 { eventModifiers.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { eventModifiers.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { eventModifiers.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { eventModifiers.insert(.command) }
        return KeyboardShortcut(KeyEquivalent(character), modifiers: eventModifiers)
    }
}
