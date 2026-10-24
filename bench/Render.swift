// Renders bench/data/manifest.json into bench/data/images/<id>.png: editor-style screenshots with syntax colours,
// optional line numbers, and for "video" conditions the degradation of a paused video frame (downscale,
// JPEG compression, upscale back to screen size). Video conditions use at least 14 pt (1080p) or 16 pt (720p),
// as tutorial makers enlarge their editor font.
//
//   swift bench/Render.swift

import AppKit
import ImageIO
import UniformTypeIdentifiers

struct Item: Decodable {
    let id, language, theme, font, condition: String
    let size, line_height, padding: Double
    let line_numbers: Bool
}

struct Theme { let background, text, keyword, string, comment, number, function, gutter: UInt32 }

let themes: [String: Theme] = [
    "dark-plus": Theme(background: 0x1E1E1E, text: 0xD4D4D4, keyword: 0x569CD6, string: 0xCE9178, comment: 0x6A9955, number: 0xB5CEA8, function: 0xDCDCAA, gutter: 0x858585),
    "light-plus": Theme(background: 0xFFFFFF, text: 0x000000, keyword: 0x0000FF, string: 0xA31515, comment: 0x008000, number: 0x098658, function: 0x795E26, gutter: 0x237893),
    "github-light": Theme(background: 0xFFFFFF, text: 0x24292F, keyword: 0xCF222E, string: 0x0A3069, comment: 0x6E7781, number: 0x0550AE, function: 0x8250DF, gutter: 0x8C959F),
    "monokai": Theme(background: 0x272822, text: 0xF8F8F2, keyword: 0xF92672, string: 0xE6DB74, comment: 0x75715E, number: 0xAE81FF, function: 0xA6E22E, gutter: 0x90908A),
    "solarized-dark": Theme(background: 0x002B36, text: 0x839496, keyword: 0x859900, string: 0x2AA198, comment: 0x586E75, number: 0xD33682, function: 0x268BD2, gutter: 0x586E75),
    "one-dark": Theme(background: 0x282C34, text: 0xABB2BF, keyword: 0xC678DD, string: 0x98C379, comment: 0x5C6370, number: 0xD19A66, function: 0x61AFEF, gutter: 0x636D83),
]

let keywords = [
    "python": "def|class|return|if|elif|else|for|while|in|not|and|or|is|None|True|False|try|except|finally|with|as|import|from|raise|yield|lambda|pass|break|continue|global|nonlocal|async|await|assert|del|self",
    "javascript": "function|const|let|var|return|if|else|for|of|in|while|do|switch|case|break|continue|new|this|class|extends|import|export|from|default|try|catch|finally|throw|typeof|instanceof|async|await|yield|null|undefined|true|false",
]

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, alpha: 1)
}

func highlight(_ code: String, language: String, font: NSFont, theme: Theme) -> NSAttributedString {
    let text = NSMutableAttributedString(string: code, attributes: [.font: font, .foregroundColor: color(theme.text)])
    let all = NSRange(location: 0, length: (code as NSString).length)
    let comment = language == "python" ? "#[^\\n]*" : "//[^\\n]*|/\\*[\\s\\S]*?\\*/"
    let string = language == "python"
        ? "\"\"\"[\\s\\S]*?\"\"\"|'''[\\s\\S]*?'''|\"(?:\\\\.|[^\"\\\\\\n])*\"|'(?:\\\\.|[^'\\\\\\n])*'"
        : "`(?:\\\\.|[^`\\\\])*`|\"(?:\\\\.|[^\"\\\\\\n])*\"|'(?:\\\\.|[^'\\\\\\n])*'"
    // Later rules win, so strings and comments override keywords inside them.
    for (pattern, hex) in [("\\b[A-Za-z_]\\w*(?=\\()", theme.function), ("\\b\\d+(\\.\\d+)?\\b", theme.number),
                           ("\\b(\(keywords[language]!))\\b", theme.keyword), (string, theme.string), (comment, theme.comment)] {
        for match in try! NSRegularExpression(pattern: pattern).matches(in: code, range: all) {
            text.addAttribute(.foregroundColor, value: color(hex), range: match.range)
        }
    }
    return text
}

func canvas(width: Double, height: Double, scale: Double, _ draw: () -> Void) -> CGImage {
    let context = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: height * scale)
    context.scaleBy(x: scale, y: -scale)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()!
}

func resized(_ image: CGImage, width: Int, height: Int) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

func jpegRoundTrip(_ image: CGImage, quality: Double) -> CGImage {
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    precondition(CGImageDestinationFinalize(destination))
    return CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(data, nil)!, 0, nil)!
}

/// A paused video frame shown full screen: fewer source pixels, compression artefacts, then upscaled.
func degraded(_ image: CGImage, condition: String) -> CGImage {
    let (factor, quality) = condition == "video-720p" ? (0.375, 0.45) : condition == "video-1080p" ? (0.5, 0.6) : (1.0, 1.0)
    guard factor < 1 else { return image }
    let small = resized(image, width: Int(Double(image.width) * factor), height: Int(Double(image.height) * factor))
    return resized(jpegRoundTrip(small, quality: quality), width: image.width, height: image.height)
}

func render(_ item: Item, code: String) -> CGImage {
    let size = item.condition == "video-720p" ? max(item.size, 16) : item.condition == "video-1080p" ? max(item.size, 14) : item.size
    let font = item.font == "SF Mono" ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular) : NSFont(name: item.font, size: size)!
    let theme = themes[item.theme]!
    let text = highlight(code, language: item.language, font: font, theme: theme)
    let lines = code.components(separatedBy: "\n")
    let lineHeight = (size * item.line_height).rounded()
    let digitWidth = NSAttributedString(string: "0", attributes: [.font: font]).size().width
    let digits = max(2, String(lines.count).count)
    let gutter = item.line_numbers ? digitWidth * Double(digits + 3) : 0
    let widest = lines.map { NSAttributedString(string: $0, attributes: [.font: font]).size().width }.max() ?? 0
    let width = (item.padding * 2 + gutter + widest).rounded(.up)
    let height = (item.padding * 2 + Double(lines.count) * lineHeight).rounded(.up)
    let glyphHeight = font.ascender - font.descender

    let image = canvas(width: width, height: height, scale: 2) {
        color(theme.background).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        var location = 0
        for (index, line) in lines.enumerated() {
            let y = item.padding + Double(index) * lineHeight + (lineHeight - glyphHeight) / 2
            if item.line_numbers {
                let number = NSAttributedString(string: "\(index + 1)", attributes: [.font: font, .foregroundColor: color(theme.gutter)])
                number.draw(at: NSPoint(x: item.padding + digitWidth * Double(digits) - number.size().width, y: y))
            }
            let range = NSRange(location: location, length: (line as NSString).length)
            text.attributedSubstring(from: range).draw(at: NSPoint(x: item.padding + gutter, y: y))
            location += range.length + 1
        }
    }
    return degraded(image, condition: item.condition)
}

let data = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "bench/data")
let items = try JSONDecoder().decode([Item].self, from: Data(contentsOf: data.appendingPathComponent("manifest.json")))
let imagesDirectory = data.appendingPathComponent("images")
try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
for item in items {
    let code = try String(contentsOf: data.appendingPathComponent("truth/\(item.id).txt"), encoding: .utf8)
        .trimmingCharacters(in: .newlines)
    let destination = CGImageDestinationCreateWithURL(imagesDirectory.appendingPathComponent("\(item.id).png") as CFURL,
                                                      UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, render(item, code: code), nil)
    precondition(CGImageDestinationFinalize(destination))
}
print("\(items.count) images -> \(imagesDirectory.path)")
