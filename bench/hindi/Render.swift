import AppKit
// Renders bench/hindi/sentences.tsv as screenshots: 18 pt at 2× (Retina) and 14 pt at 1×, black on white, in the
// system font (macOS draws Devanagari in Kohinoor Devanagari). Writes <id>-<size>.png and .txt to the output folder.
// Usage: swiftc -O bench/hindi/Render.swift -o /tmp/render-hindi && /tmp/render-hindi bench/hindi/sentences.tsv bench/data-hindi
let arguments = CommandLine.arguments
let rows = try String(contentsOfFile: arguments[1], encoding: .utf8).split(separator: "\n").dropFirst().map { $0.split(separator: "\t") }
let output = URL(fileURLWithPath: arguments[2])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for row in rows {
    for (size, scale) in [(18.0, 2.0), (14.0, 1.0)] {
        let text = NSAttributedString(string: String(row[2]), attributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: NSColor.black])
        let bounds = text.size()
        let width = Int((bounds.width + 40) * scale), height = Int((bounds.height + 30) * scale)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: Double(width) / scale, height: Double(height) / scale)
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: Double(width) / scale, height: Double(height) / scale).fill()
        text.draw(at: NSPoint(x: 20, y: 15))
        let name = "\(row[0])-\(Int(size))pt"
        try rep.representation(using: .png, properties: [:])!.write(to: output.appending(path: name + ".png"))
        try String(row[2]).write(to: output.appending(path: name + ".txt"), atomically: true, encoding: .utf8)
    }
}
