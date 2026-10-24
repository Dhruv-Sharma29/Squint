import AppKit
import Carbon.HIToolbox
import Observation

@MainActor @Observable
final class CaptureModel {
    enum Status: Equatable {
        case idle, copied
        case failed(String)
    }

    var codeMode = true
    private(set) var status = Status.idle
    private(set) var hotKeyAvailable = false

    var symbol: String {
        switch status {
        case .idle: "text.viewfinder"
        case .copied: "checkmark.circle"
        case .failed: "exclamationmark.triangle"
        }
    }

    init() {
        hotKeyAvailable = HotKey.register(keyCode: kVK_ANSI_2, modifiers: cmdKey | shiftKey) { [weak self] in
            Task { await self?.capture() }
        }
    }

    /// Select a screen region and copy its text. `code` overrides the Code Mode toggle.
    func capture(code: Bool? = nil) async {
        status = .idle
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            status = .failed(String(localized: "Allow Squint under System Settings › Privacy & Security › Screen Recording, then try again."))
            return
        }
        do {
            guard let shot = try await ScreenCapture.region() else { return } // Esc pressed
            await recognize(shot, code: code ?? codeMode)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Copy the text in an image already on the clipboard, such as a screenshot copied from chat.
    func readClipboard(code: Bool? = nil) async {
        status = .idle
        do {
            guard let image = try ClipboardImage.file() else {
                status = .failed(String(localized: "The clipboard has no image."))
                return
            }
            await recognize(image, code: code ?? codeMode)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// `squint://capture` or `squint://clipboard`, with optional `?mode=code` or `?mode=plain`.
    func open(_ url: URL) async {
        let mode = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "mode" }?.value
        let code = mode.map { $0 != "plain" }
        switch url.host() {
        case "capture": await capture(code: code)
        case "clipboard": await readClipboard(code: code)
        default: status = .failed(String(localized: "Unknown Squint link: \(url.absoluteString)"))
        }
    }

    private func recognize(_ image: URL, code: Bool) async {
        do {
            let text = try await Self.read(image, code: code)
            guard !text.isEmpty else {
                status = .failed(String(localized: "No text found."))
                return
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            status = .copied
            try? await Task.sleep(for: .seconds(1.5))
            if status == .copied { status = .idle }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// OCR off the main actor, then delete the image: it may hold private data.
    /// Plain `nonisolated async` rather than `@concurrent` keeps the package buildable with Swift 6.0 (Xcode 16 on macOS 14).
    private nonisolated static func read(_ url: URL, code: Bool) async throws -> String {
        defer { try? FileManager.default.removeItem(at: url) }
        return try Recognizer.text(at: url, code: code)
    }
}
