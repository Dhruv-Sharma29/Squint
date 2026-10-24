import AppKit
import Observation

@MainActor @Observable
final class CaptureModel {
    enum Status: Equatable {
        case idle, copied, needsPermission
        /// A short message for the menu; menus can't wrap, so long text would stretch them across the screen.
        case failed(String)
    }

    /// The longest message the menu shows; longer ones are cut, while VoiceOver still announces them in full.
    static let menuMessageLimit = 48

    let preferences: Preferences
    private(set) var status = Status.idle
    private(set) var hotKeyAvailable = false
    /// The text of the scroll capture under way, or nil when none is. Each capture is added to it by the lines they
    /// share (`ScrollMerge`), and the whole is copied.
    private(set) var scrollCapture: String?

    /// True from the moment a capture starts until its text is copied; a second request meanwhile is ignored.
    private(set) var isBusy = false

    /// SF Symbol shown briefly in place of the logo after a capture; nil while idle.
    var statusSymbol: String? {
        switch status {
        case .idle: nil
        case .copied: "checkmark.circle"
        case .failed, .needsPermission: "exclamationmark.triangle"
        }
    }

    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private let screenAccess: @MainActor () -> Bool
    @ObservationIgnored private let captureRegion: @MainActor () async throws -> URL?
    @ObservationIgnored private let openLink: @MainActor (URL) -> Void

    /// The defaults are the real system; tests pass a private pasteboard and a stand-in for the selection overlay.
    init(preferences: Preferences = Preferences(),
         pasteboard: NSPasteboard = .general,
         screenAccess: @escaping @MainActor () -> Bool = CaptureModel.requestScreenAccess,
         captureRegion: @escaping @MainActor () async throws -> URL? = { try await ScreenCapture.region() },
         openLink: @escaping @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) },
         registersHotKey: Bool = true) {
        self.preferences = preferences
        self.pasteboard = pasteboard
        self.screenAccess = screenAccess
        self.captureRegion = captureRegion
        self.openLink = openLink
        if registersHotKey {
            hotKeyAvailable = registerHotKey(preferences.shortcut)
        }
    }

    /// True when Squint may capture the screen; otherwise asks macOS to show the Screen Recording prompt.
    static func requestScreenAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        CGRequestScreenCaptureAccess()
        return false
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
        guard screenAccess() else {
            // macOS applies a new Screen Recording permission only after the app restarts.
            status = .needsPermission
            announce(String(localized: "Allow Squint under System Settings › Privacy & Security › Screen Recording, then quit and reopen Squint."))
            return nil
        }
        do {
            guard let shot = try await captureRegion() else { // Esc pressed
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
            guard let image = try ClipboardImage.file(from: pasteboard) else {
                fail(String(localized: "No image on the clipboard"))
                return nil
            }
            return await recognize(image, code: code ?? preferences.codeMode)
        } catch {
            fail(error.localizedDescription)
            return nil
        }
    }

    /// Select a screen region and copy the table in it, as Markdown or tab-separated values.
    @discardableResult
    func captureTable() async -> String? {
        guard TableReader.isAvailable else {
            fail(String(localized: "Tables need macOS 26 or later"))
            return nil
        }
        guard begin() else { return nil }
        defer { isBusy = false }
        guard screenAccess() else {
            status = .needsPermission
            return nil
        }
        do {
            guard let shot = try await captureRegion() else {
                status = .idle
                return nil
            }
            let rows = try await Self.readTable(shot)
            guard let rows, !rows.isEmpty else {
                fail(String(localized: "No table found. Select the whole table."))
                return nil
            }
            let text = TableReader.formatted(rows, as: preferences.tableFormat)
            copy(text)
            announce(String(localized: "Copied a table with \(rows.count) rows"))
            return text
        } catch {
            fail(error.localizedDescription)
            return nil
        }
    }

    /// Starts a scroll capture: capture, scroll, capture again, and the parts are joined without repeating lines.
    func startScrollCapture() {
        scrollCapture = ""
        announce(String(localized: "Scroll capture started. Capture, scroll, and capture again."))
    }

    func finishScrollCapture() {
        scrollCapture = nil
        announce(String(localized: "Scroll capture finished"))
    }

    func open(_ url: URL) async {
        switch LinkCommand(url) {
        case .capture(let code): await capture(code: code)
        case .clipboard(let code): await readClipboard(code: code)
        case .table: await captureTable()
        case .settings: break // windows belong to AppDelegate, which handles this link before it gets here
        case nil: fail(String(localized: "Unknown link: \(url.absoluteString)"))
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
            let read = try await Self.read(image, code: code, language: preferences.language, words: preferences.customWords)
            guard !read.isEmpty else {
                fail(String(localized: "No text found. Try a larger area."))
                return nil
            }
            let whole = scrollCapture.map { ScrollMerge.merging($0, read) } ?? read
            if scrollCapture != nil { scrollCapture = whole }
            let text = code && preferences.copyAsMarkdown ? MarkdownFence.wrapping(whole) : whole
            copy(text)
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count
            announce(String(localized: "Copied \(lines) lines"))
            if preferences.openFirstLink, let link = Self.firstLink(in: text) {
                openLink(link)
            }
            return text
        } catch {
            fail(error.localizedDescription)
            return nil
        }
    }

    /// Puts `text` on the clipboard, with the sound and the menu bar tick that confirm it.
    private func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        status = .copied
        if preferences.playSound {
            NSSound(named: "Tink")?.play()
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if status == .copied { status = .idle }
        }
    }

    /// Opens System Settings at Privacy & Security › Screen Recording.
    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func fail(_ message: String) {
        let limit = Self.menuMessageLimit
        status = .failed(message.count > limit ? String(message.prefix(limit - 1)) + "…" : message)
        announce(message)
    }

    /// VoiceOver feedback: the menu bar icon change alone isn't perceivable without sight. Skipped when Squint isn't
    /// running as an app (tests, the CLI): creating the app object there can block on a headless Mac.
    private func announce(_ message: String) {
        guard let app = NSApp else { return }
        NSAccessibility.post(element: app, notification: .announcementRequested, userInfo: [
            .announcement: message,
            .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])
    }

    /// OCR off the main actor, then delete the image: it may hold private data.
    /// Plain `nonisolated async` rather than `@concurrent` keeps the package buildable with Swift 6.0 (Xcode 16 on macOS 14).
    private nonisolated static func read(_ url: URL, code: Bool, language: String?, words: [String]) async throws -> String {
        defer { try? FileManager.default.removeItem(at: url) }
        return Recognizer.applyingCustomWords(try await Recognizer.text(at: url, code: code, language: language), words: words)
    }

    /// The table in the image, then the image deleted: it may hold private data.
    private nonisolated static func readTable(_ url: URL) async throws -> [[String]]? {
        defer { try? FileManager.default.removeItem(at: url) }
        return try await TableReader.table(at: url)
    }

    /// The first web address in `text`: http and https only, so a captured `file:` or app link never opens anything.
    static func firstLink(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).lazy
            .compactMap(\.url).first { ["http", "https"].contains($0.scheme?.lowercased()) }
    }
}
