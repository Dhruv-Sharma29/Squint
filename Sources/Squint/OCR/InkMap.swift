import CoreGraphics

/// Pixel access for spotting glyphs Vision skipped, such as a lone `}`.
// ponytail: background = top-left pixel, fine for flat editor themes; gradients/wallpapers need a real background estimate.
struct InkMap {
    /// Premultiplied RGBA, top row first.
    let pixels: [UInt8]
    let width: Int
    let height: Int

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

    /// The most common colour around the image's edge, averaged within its group of near-identical colours.
    var background: (Int, Int, Int) {
        var groups: [Int: (count: Int, sum: (Int, Int, Int))] = [:]
        func add(_ x: Int, _ y: Int) {
            let i = (y * width + x) * 4
            let c = (Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2]))
            let key = (c.0 / 8) << 10 | (c.1 / 8) << 5 | c.2 / 8
            let group = groups[key, default: (0, (0, 0, 0))]
            groups[key] = (group.count + 1, (group.sum.0 + c.0, group.sum.1 + c.1, group.sum.2 + c.2))
        }
        for x in 0..<width { add(x, 0); add(x, height - 1) }
        for y in 0..<height { add(0, y); add(width - 1, y) }
        guard let top = groups.values.max(by: { $0.count < $1.count }) else { return (255, 255, 255) }
        return (top.sum.0 / top.count, top.sum.1 / top.count, top.sum.2 / top.count)
    }

    private func isInk(_ x: Int, _ y: Int) -> Bool {
        let offset = (y * width + x) * 4
        return (0..<3).contains { abs(Int(pixels[offset + $0]) - Int(pixels[$0])) > 64 }
    }
}
