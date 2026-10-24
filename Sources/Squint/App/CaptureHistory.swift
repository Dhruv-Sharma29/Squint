import Foundation
import Observation

/// The last captures, kept only when the person turns history on, only on this Mac, in a file only they can read.
@MainActor @Observable
final class CaptureHistory {
    struct Entry: Codable, Equatable, Identifiable {
        var id = UUID()
        let text: String
        let date: Date
    }

    static let limit = 20

    private(set) var entries: [Entry] = []
    @ObservationIgnored private let file: URL

    /// The default is `~/Library/Application Support/Squint/history.json`; tests pass a temporary file.
    init(file: URL = URL.applicationSupportDirectory.appending(path: "Squint/history.json")) {
        self.file = file
        entries = (try? JSONDecoder().decode([Entry].self, from: Data(contentsOf: file))) ?? []
    }

    /// Newest first; a capture identical to the newest isn't added twice.
    func add(_ text: String) {
        guard entries.first?.text != text else { return }
        entries.insert(Entry(text: text, date: .now), at: 0)
        entries = Array(entries.prefix(Self.limit))
        save()
    }

    /// Forgets every entry and deletes the file.
    func clear() {
        entries = []
        try? FileManager.default.removeItem(at: file)
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Owner-only permissions are the protection. Data Protection's `.completeFileProtection` made the write fail
            // in some environments (the temporary file for the atomic write was refused) and adds nothing here.
            try JSONEncoder().encode(entries).write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path(percentEncoded: false))
        } catch {
            // History is a convenience: a capture still reaches the clipboard if it can't be saved.
        }
    }
}
