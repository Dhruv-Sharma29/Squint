import AppKit
import UniformTypeIdentifiers

enum ClipboardImage {
    /// A temporary copy of the image on the clipboard, or nil when it holds no image. The caller deletes it.
    ///
    /// An image file copied in Finder is checked first: Finder also puts the file's *icon* on the clipboard
    /// as TIFF, and reading that instead would return the icon rather than the image.
    static func file(from pasteboard: NSPasteboard = .general) throws -> URL? {
        let copy = URL.temporaryDirectory.appending(path: "squint-\(UUID().uuidString)")
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: [UTType.image.identifier],
        ]
        if let file = pasteboard.readObjects(forClasses: [NSURL.self], options: options)?.first as? URL {
            try FileManager.default.copyItem(at: file, to: copy) // a copy, so deleting it never touches the original
            return copy
        }
        guard let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) else { return nil }
        try data.write(to: copy)
        return copy
    }
}
