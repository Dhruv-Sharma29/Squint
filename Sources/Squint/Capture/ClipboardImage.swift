import AppKit

enum ClipboardImage {
    /// Writes the clipboard's image to a temporary file, or returns nil when the clipboard holds no image.
    static func file() throws -> URL? {
        let pasteboard = NSPasteboard.general
        guard let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) else { return nil }
        let url = URL.temporaryDirectory.appending(path: "squint-\(UUID().uuidString)")
        try data.write(to: url)
        return url
    }
}
