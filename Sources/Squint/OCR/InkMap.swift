import CoreGraphics

/// Pixel access for spotting glyphs Vision skipped, such as a lone `}`.
// ponytail: background = top-left pixel, fine for flat editor themes; gradients/wallpapers need a real background estimate.
struct InkMap {
    private let pixels: [UInt8]
    private let width: Int
    private let height: Int

    init?(_ image: CGImage) {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.pixels = pixels
        self.width = width
        self.height = height
    }

    /// Leftmost glyph pixel (normalized x) in a band around `midY` (Vision coordinates, origin bottom-left), or nil if the
    /// band is empty. Scanning starts at normalized x `from`, so an editor's line-number gutter can be skipped.
    func leftEdge(midY: Double, halfHeight: Double, from: Double = 0) -> Double? {
        let top = max(0, Int((1 - midY - halfHeight) * Double(height)))
        let bottom = min(height, Int((1 - midY + halfHeight) * Double(height)))
        let start = min(width, max(0, Int((from * Double(width)).rounded(.up))))
        guard top < bottom else { return nil }
        for x in start..<width {
            for y in top..<bottom where isInk(x, y) {
                return Double(x) / Double(width)
            }
        }
        return nil
    }

    private func isInk(_ x: Int, _ y: Int) -> Bool {
        let offset = (y * width + x) * 4
        return (0..<3).contains { abs(Int(pixels[offset + $0]) - Int(pixels[$0])) > 64 }
    }
}
