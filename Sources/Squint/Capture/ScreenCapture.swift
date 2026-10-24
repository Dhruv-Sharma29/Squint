import Foundation

/// The system's own region picker (same UI as ⌘⇧4), so Squint needs no overlay of its own.
enum ScreenCapture {
    /// A temporary PNG of the selected region, or nil if the user pressed Esc.
    static func region() async throws -> URL? {
        let url = URL.temporaryDirectory.appending(path: "squint-\(UUID().uuidString).png")
        let process = Process()
        process.executableURL = URL(filePath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", url.path(percentEncoded: false)]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            process.terminationHandler = { _ in continuation.resume() }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }
}
