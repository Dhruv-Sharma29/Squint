import AppKit

/// Test support: renders code like an editor screenshot (monospaced, dark theme) and writes a temporary PNG.
enum CodeImage {
    struct RenderError: Error {}

    static func write(_ code: String) throws -> URL {
        let font = NSFont.monospacedSystemFont(ofSize: 26, weight: .regular)
        let text = NSAttributedString(string: code, attributes: [.font: font, .foregroundColor: NSColor(white: 0.9, alpha: 1)])
        let size = text.size()
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width) + 80, pixelsHigh: Int(size.height) + 80,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { throw RenderError() }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor(white: 0.12, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh).fill()
        text.draw(at: NSPoint(x: 40, y: 40))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw RenderError() }
        let url = URL.temporaryDirectory.appending(path: "squint-test-\(UUID().uuidString).png")
        try png.write(to: url)
        return url
    }
}
