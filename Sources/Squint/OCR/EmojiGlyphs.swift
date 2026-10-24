import CoreGraphics
import CoreText
import Foundation

/// Every emoji macOS draws in colour, rendered in Apple Color Emoji, the font Mac apps use for emoji: what
/// `EmojiFinder` compares a screenshot against.
enum EmojiGlyphs {
    static let side = 48

    struct Glyph {
        let emoji: String
        /// Premultiplied RGBA, `side` × `side`, top row first.
        let pixels: [UInt8]
    }

    // ponytail: about 1,470 glyphs × 9 KB = 13 MB, kept once a capture first needs them (0.1 s to render).
    static let all: [Glyph] = candidates().compactMap(render)

    /// Default-emoji scalars, text-default ones with VS16 (such as ❤️), and country flags.
    static func candidates() -> [String] {
        var out: [String] = []
        for range: ClosedRange<UInt32> in [0x00A9...0x00AE, 0x2000...0x3300, 0x1F000...0x1FAFF] {
            for value in range {
                guard let scalar = Unicode.Scalar(value), scalar.properties.isEmoji else { continue }
                out.append(scalar.properties.isEmojiPresentation ? String(scalar) : String(scalar) + "\u{FE0F}")
            }
        }
        // Territories Apple draws with another country's flag: the country is the likelier reading.
        let sharedFlags: Set = ["CP", "MF", "EA", "DG", "HM", "BV", "SJ", "UM"]
        for region in Locale.Region.isoRegions {
            let code = region.identifier
            guard code.count == 2, code.allSatisfy(\.isLetter), !sharedFlags.contains(code) else { continue }
            out.append(String(String.UnicodeScalarView(code.unicodeScalars.compactMap { Unicode.Scalar($0.value - 65 + 0x1F1E6) })))
        }
        return out
    }

    /// Nil when the font has no colour glyph for it.
    private static func render(_ emoji: String) -> Glyph? {
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            let font = CTFontCreateWithName("AppleColorEmoji" as CFString, 34, nil)
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: emoji, attributes: [.init(kCTFontAttributeName as String): font]))
            context.textPosition = CGPoint(x: 4, y: 12) // baseline above the descender
            CTLineDraw(line, context)
            return true
        }
        let colourful = stride(from: 0, to: pixels.count, by: 4).count { i in
            let channels = [Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2])]
            return pixels[i + 3] > 128 && channels.max()! - channels.min()! > 40
        }
        return drawn && colourful > 20 ? Glyph(emoji: emoji, pixels: pixels) : nil
    }
}
