import AppKit
import Observation

@MainActor @Observable
final class CaptureModel {
    enum Status: Equatable {
        case idle, copied
        case failed(String)
    }

    let preferences: Preferences
    private(set) var status = Status.idle
    private(set) var hotKeyAvailable = false
    /// True from the moment a capture starts until its text is copied; a second request meanwhile is ignored.
    private(set) var isBusy = false

    /// SF Symbol shown briefly in place of the logo after a capture; nil while idle.
    var statusSymbol: String? {
        switch status {
        case .idle: nil
        case .copied: "checkmark.circle"
        case .failed: "exclamationmark.triangle"
        }
    }

    init(preferences: Preferences = Preferences()) {
        self.preferences = preferences
        hotKeyAvailable = registerHotKey(preferences.shortcut)
    }

    /// Switches to `shortcut`. If another app already owns it, keeps the current one and returns false.
    @discardableResult
    func changeShortcut(to shortcut: Shortcut) -> Bool {
        if registerHotKey(shortcut) {
            preferences.shortcut = shortcut
            hotKeyAvailable = true
            return true
        }
        hotKeyAvailable = registerHotKey(preferences.shortcut)
        return false
    }

    /// Pauses the global shortcut, so recording a new one doesn't trigger a capture.
    func suspendShortcut() {
        HotKey.unregister()
    }

    func resumeShortcut() {
        hotKeyAvailable = registerHotKey(preferences.shortcut)
    }

    /// Select a screen region and copy its text. `code` overrides the Code Mode setting.
    /// Returns the copied text, or nil if the capture was cancelled or failed.
    @discardableResult
    func capture(code: Bool? = nil) async -> String? {
        guard begin() else { return nil }
        defer { isBusy = false }
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            // macOS applies a new Screen Recording permission only after the app restarts.
            fail(String(localized: "Allow Squint under System Settings › Privacy & Security › Screen Recording, then quit and reopen Squint."))
            return nil
        }
        do {
            guard let shot = try await ScreenCapture.region() else { // Esc pressed
                status = .idle
                return nil
            }
            return await recognize(shot, code: code ?? preferences.codeMode)
        } catch {
            fail(error.localizedDescription)
            return nil
        }
    }

    /// Copy the text in an image already on the clipboard, or in an image file copied in Finder.
    @discardableResult
    func readClipboard(code: Bool? = nil) async -> String? {
        guard begin() else { return nil }
        defer { isBusy = false }
        do {
            guard let image = try ClipboardImage.file() else {
                fail(String(localized: "The clipboard has no image. Copy a screenshot or an image file, then try again."))
                return nil
            }
            return await recognize(image, code: code ?? preferences.codeMode)
        } catch {
            fail(error.localizedDescription)
            return nil
        }
    }

    func open(_ url: URL) async {
        switch LinkCommand(url) {
        case .capture(let code): await capture(code: code)
        case .clipboard(let code): await readClipboard(code: code)
        case nil: fail(String(localized: "Unknown Squint link: \(url.absoluteString)"))
        }
    }

    private func begin() -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        status = .idle
        return true
    }

    private func registerHotKey(_ shortcut: Shortcut) -> Bool {
        HotKey.register(shortcut) { [weak self] in
            Task { await self?.capture() }
        }
    }

    private func recognize(_ image: URL, code: Bool) async -> String? {
        do {
            let text = try await Self.read(image, code: code, language: preferences.language)
            guard !text.isEmpty else {
                fail(String(localized: "No text found. Try selecting a larger area, or zoom in first."))
                return nil
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            status = .copied
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count
            announce(String(localized: "Copied \(lines) lines"))
            if preferences.playSound {
                NSSound(named: "Tink")?.play()
            }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                if status == .copied { status = .idle }
            }
            return text
        } catch {
            fail(error.localizedDescription)
            return nil
        }
    }

    private func fail(_ message: String) {
        status = .failed(message)
        announce(message)
    }

    /// VoiceOver feedback: the menu bar icon change alone isn't perceivable without sight.
    private func announce(_ message: String) {
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: message,
            .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])
    }

    /// OCR off the main actor, then delete the image: it may hold private data.
    /// Plain `nonisolated async` rather than `@concurrent` keeps the package buildable with Swift 6.0 (Xcode 16 on macOS 14).
    private nonisolated static func read(_ url: URL, code: Bool, language: String?) async throws -> String {
        defer { try? FileManager.default.removeItem(at: url) }
        return try Recognizer.text(at: url, code: code, language: language)
    }
}
