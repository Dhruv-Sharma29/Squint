// Generates the README media from real Squint output:
//   docs/images/comparison.png  one screenshot, read by plain Vision OCR and by Squint, checked line by line
//   docs/images/demo.gif        the capture flow; the pasted text is Squint's actual result on the frame shown
//
// Run from the repository root:
//   swift build -c release
//   swiftc Sources/Squint/App/MenuBarIcon.swift scripts/ReadmeMedia/main.swift -o .build/readme-media
//   .build/readme-media

import AppKit
import ImageIO
import UniformTypeIdentifiers

let sample = """
function groupBy(items, key) {
  const groups = {};
  for (const item of items) {
    const k = item[key];
    if (!groups[k]) {
      groups[k] = [];
    }
    groups[k].push(item);
  }

  return groups;
}
"""

let root = URL(filePath: FileManager.default.currentDirectoryPath)
let imagesDirectory = root.appending(path: "docs/images")
let squint = root.appending(path: ".build/release/Squint")
let work = URL.temporaryDirectory.appending(path: "squint-readme-media")
try? FileManager.default.removeItem(at: work)
try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

// MARK: - Palette (from the app icon)

extension NSColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(srgbRed: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, alpha: alpha)
    }
}

let desktop = NSColor(hex: 0x0E1326)
let menuBar = NSColor(hex: 0x1A2036)
let windowFill = NSColor(hex: 0x161925)
let titleBar = NSColor(hex: 0x222638)
let videoBlack = NSColor(hex: 0x0B0D14)
let textColor = NSColor(hex: 0xE6E8F0)
let dimColor = NSColor(hex: 0x8A90A6)
let keywordColor = NSColor(hex: 0xC792EA)
let punctuationColor = NSColor(hex: 0x89DDFF)
let accent = NSColor(hex: 0x5B7CFA)
let good = NSColor(hex: 0x3FB950)
let bad = NSColor(hex: 0xF85149)

// MARK: - Drawing helpers

/// A top-left-origin drawing surface; `scale` 2 gives Retina-resolution output.
func canvas(width: Double, height: Double, scale: Double, _ draw: () -> Void) -> CGImage {
    let context = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: height * scale)
    context.scaleBy(x: scale, y: -scale)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()!
}

func savePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination))
}

func monospaced(_ size: Double) -> NSFont { .monospacedSystemFont(ofSize: size, weight: .regular) }

/// Minimal JavaScript colouring: keywords and punctuation.
func highlighted(_ code: String, size: Double) -> NSAttributedString {
    let string = NSMutableAttributedString(string: code, attributes: [.font: monospaced(size), .foregroundColor: textColor])
    let range = NSRange(location: 0, length: (code as NSString).length)
    for (pattern, color) in [("\\b(function|const|for|of|if|return)\\b", keywordColor), ("[{}()\\[\\];!]", punctuationColor)] {
        for match in try! NSRegularExpression(pattern: pattern).matches(in: code, range: range) {
            string.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
    return string
}

@discardableResult
func label(_ string: String, at point: NSPoint, size: Double, weight: NSFont.Weight = .regular,
           color: NSColor = textColor, centered: Bool = false) -> NSSize {
    let text = NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
    let measured = text.size()
    text.draw(at: NSPoint(x: centered ? point.x - measured.width / 2 : point.x, y: point.y))
    return measured
}

func roundedRect(_ rect: NSRect, radius: Double, fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    NSImage(size: image.size, flipped: false) { rect in
        image.draw(in: rect)
        color.set()
        rect.fill(using: .sourceAtop)
        return true
    }
}

/// A macOS-style window; returns the content area below the title bar.
func window(_ frame: NSRect, title: String) -> NSRect {
    roundedRect(frame, radius: 12, fill: windowFill)
    let bar = NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: 34)
    roundedRect(bar, radius: 12, fill: titleBar)
    NSRect(x: bar.minX, y: bar.midY, width: bar.width, height: bar.height / 2).fill()
    for (index, hex) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
        NSColor(hex: UInt32(hex)).setFill()
        NSBezierPath(ovalIn: NSRect(x: frame.minX + 14 + Double(index) * 20, y: bar.midY - 6, width: 12, height: 12)).fill()
    }
    label(title, at: NSPoint(x: frame.midX, y: bar.midY - 8), size: 12.5, weight: .medium, color: dimColor, centered: true)
    NSColor.white.withAlphaComponent(0.08).setStroke()
    NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12).stroke()
    return NSRect(x: frame.minX, y: bar.maxY, width: frame.width, height: frame.height - bar.height)
}

func run(_ arguments: [String]) -> String {
    let process = Process()
    process.executableURL = squint
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    try! process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    precondition(process.terminationStatus == 0, "squint \(arguments) failed")
    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)
}

// MARK: - 1. The screenshot Squint reads

let codeSize = 15.0
let inputCode = highlighted(sample, size: codeSize)
let inputPadding = 28.0
let inputWidth = inputCode.size().width + inputPadding * 2, inputHeight = inputCode.size().height + inputPadding * 2
let inputImage = canvas(width: inputWidth, height: inputHeight, scale: 2) {
    videoBlack.setFill()
    NSRect(x: 0, y: 0, width: inputWidth, height: inputHeight).fill()
    inputCode.draw(at: NSPoint(x: inputPadding, y: inputPadding))
}
let inputURL = work.appending(path: "groupBy.png")
savePNG(inputImage, to: inputURL)
try sample.write(to: work.appending(path: "groupBy.txt"), atomically: true, encoding: .utf8)

// MARK: - 2. Real output and scores

let squintOutput = run([inputURL.path(percentEncoded: false)])
let plainOutput = run(["--plain", inputURL.path(percentEncoded: false)])
let report = run(["eval", work.path(percentEncoded: false)])
let truthLines = sample.components(separatedBy: "\n")

func characterErrorRate(_ system: String) -> Double {
    let row = report.split(separator: "\n").first { $0.hasPrefix("groupBy.png\t\(system)\t") }!
    return Double(row.split(separator: "\t")[2].replacing(",", with: "."))!
}

func matches(_ output: String) -> [Bool] {
    output.components(separatedBy: "\n").enumerated().map { $0.offset < truthLines.count && truthLines[$0.offset] == $0.element }
}

print("Squint output:\n\(squintOutput)\n\nPlain output:\n\(plainOutput)\n\n\(report)")

// MARK: - 3. Comparison image

let panelWidth = 400.0, margin = 32.0, gap = 20.0, rowHeight = 21.0, headerHeight = 96.0, panelHeader = 64.0
let comparisonWidth = margin * 2 + panelWidth * 3 + gap * 2
let inputDisplayHeight = inputHeight * (panelWidth - 32) / inputWidth
let maxRows = Double(max(squintOutput.components(separatedBy: "\n").count, plainOutput.components(separatedBy: "\n").count))
let bodyHeight = max(inputDisplayHeight, maxRows * rowHeight)
let panelHeight = panelHeader + bodyHeight + 56
let comparisonHeight = headerHeight + panelHeight + margin

func outputPanel(_ text: String, in rect: NSRect) {
    let lineMatches = matches(text)
    let space = NSAttributedString(string: " ", attributes: [.font: monospaced(12.5)]).size().width
    for (index, line) in text.components(separatedBy: "\n").enumerated() {
        let row = NSRect(x: rect.minX, y: rect.minY + Double(index) * rowHeight, width: rect.width, height: rowHeight)
        roundedRect(row.insetBy(dx: 0, dy: 1.5), radius: 4, fill: (lineMatches[index] ? good : bad).withAlphaComponent(0.16))
        let indent = line.prefix { $0 == " " }.count
        let dots = NSAttributedString(string: String(repeating: "·", count: indent),
                                      attributes: [.font: monospaced(12.5), .foregroundColor: dimColor.withAlphaComponent(0.6)])
        dots.draw(at: NSPoint(x: row.minX + 8, y: row.minY + 2))
        highlighted(String(line.dropFirst(indent)), size: 12.5).draw(at: NSPoint(x: row.minX + 8 + Double(indent) * space, y: row.minY + 2))
    }
}

func summary(_ text: String, system: String, at point: NSPoint) {
    let exact = matches(text).filter { $0 }.count
    let allExact = exact == truthLines.count && text.components(separatedBy: "\n").count == truthLines.count
    let rate = characterErrorRate(system).formatted(.percent.precision(.fractionLength(1)))
    label("\(allExact ? "✓" : "✗")  \(exact) of \(truthLines.count) lines exact  ·  \(rate) character errors",
          at: point, size: 13, weight: .semibold, color: allExact ? good : bad)
}

let comparison = canvas(width: comparisonWidth, height: comparisonHeight, scale: 2) {
    desktop.setFill()
    NSRect(x: 0, y: 0, width: comparisonWidth, height: comparisonHeight).fill()
    label("One screenshot, two results", at: NSPoint(x: margin, y: 26), size: 24, weight: .bold)
    label("Each line is checked against the original source: green matches exactly, red doesn't. Dots show indentation.",
          at: NSPoint(x: margin, y: 60), size: 13.5, color: dimColor)

    let columns = [("On screen", "A code frame from a tutorial video"),
                   ("Plain OCR", "Apple Vision, default settings"),
                   ("Squint", "Code Mode")]
    for (index, column) in columns.enumerated() {
        let rect = NSRect(x: margin + Double(index) * (panelWidth + gap), y: headerHeight, width: panelWidth, height: panelHeight)
        roundedRect(rect, radius: 14, fill: windowFill)
        if index == 2 {
            accent.setStroke()
            let outline = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 14, yRadius: 14)
            outline.lineWidth = 2
            outline.stroke()
        }
        label(column.0, at: NSPoint(x: rect.minX + 18, y: rect.minY + 14), size: 16, weight: .bold, color: index == 2 ? accent : textColor)
        label(column.1, at: NSPoint(x: rect.minX + 18, y: rect.minY + 37), size: 12.5, color: dimColor)
        let body = NSRect(x: rect.minX + 16, y: rect.minY + panelHeader, width: panelWidth - 32, height: bodyHeight)
        let footer = NSPoint(x: rect.minX + 18, y: rect.maxY - 38)
        switch index {
        case 0:
            NSImage(cgImage: inputImage, size: .zero).draw(in: NSRect(x: body.minX, y: body.minY, width: body.width, height: inputDisplayHeight),
                                                          from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            label("Selected with ⌘⇧2", at: footer, size: 13, weight: .semibold, color: dimColor)
        case 1:
            outputPanel(plainOutput, in: body)
            summary(plainOutput, system: "plain", at: footer)
        default:
            outputPanel(squintOutput, in: body)
            summary(squintOutput, system: "squint", at: footer)
        }
    }
}
savePNG(comparison, to: imagesDirectory.appending(path: "comparison.png"))

// MARK: - 4. Demo GIF

struct Scene {
    var step = 1
    var keycap: String?
    var selection: Double?
    var flash = 0.0
    var copied = false
    var editor = false
    var pasted = false
}

let demoWidth = 1200.0, demoHeight = 680.0
let videoFrame = NSRect(x: 40, y: 64, width: 650, height: 500)
let editorFrame = NSRect(x: 730, y: 112, width: 430, height: 400)
let glyph = MainActor.assumeIsolated { MenuBarIcon.image }
let check = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil)!
    .withSymbolConfiguration(.init(pointSize: 15, weight: .regular))!
let squintLines = squintOutput.components(separatedBy: "\n")

func drawScene(_ scene: Scene) {
    desktop.setFill()
    NSRect(x: 0, y: 0, width: demoWidth, height: demoHeight).fill()

    // Menu bar with Squint's icon, which turns into a checkmark after a capture.
    menuBar.setFill()
    NSRect(x: 0, y: 0, width: demoWidth, height: 28).fill()
    label("Safari    File    Edit    View", at: NSPoint(x: 18, y: 6), size: 13, color: textColor.withAlphaComponent(0.85))
    tinted(scene.copied ? check : glyph, .white).draw(in: NSRect(x: demoWidth - 112, y: 6, width: 16, height: 16),
                                                      from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    label("Sat 9:41", at: NSPoint(x: demoWidth - 80, y: 6), size: 13, color: textColor.withAlphaComponent(0.85))

    // The tutorial video.
    let video = window(videoFrame, title: "JavaScript Basics · Lesson 4: Grouping Data")
    videoBlack.setFill()
    NSRect(x: video.minX, y: video.minY, width: video.width, height: video.height - 12).fill()
    let codeOrigin = NSPoint(x: video.minX + 56, y: video.minY + 44)
    inputCode.draw(at: codeOrigin)
    let track = NSRect(x: video.minX + 20, y: video.maxY - 40, width: video.width - 40, height: 4)
    roundedRect(track, radius: 2, fill: .white.withAlphaComponent(0.2))
    roundedRect(NSRect(x: track.minX, y: track.minY, width: track.width * 0.41, height: 4), radius: 2, fill: accent)
    label("▶︎   12:48 / 31:05", at: NSPoint(x: track.minX, y: track.maxY + 6), size: 12, color: dimColor)

    // The editor the code is pasted into.
    if scene.editor {
        let content = window(editorFrame, title: "groupBy.js")
        let size = 13.0, lineHeight = 20.0
        for (index, line) in (scene.pasted ? squintLines : []).enumerated() {
            let y = content.minY + 18 + Double(index) * lineHeight
            label("\(index + 1)", at: NSPoint(x: content.minX + 14, y: y + 1), size: 11.5, color: dimColor.withAlphaComponent(0.7))
            highlighted(line, size: size).draw(at: NSPoint(x: content.minX + 44, y: y))
        }
        let caretLine = scene.pasted ? Double(squintLines.count) : 0
        roundedRect(NSRect(x: content.minX + 44, y: content.minY + 20 + caretLine * lineHeight, width: 2, height: 16), radius: 1, fill: accent)
    }

    // The system selection UI.
    if let progress = scene.selection {
        let target = NSRect(origin: codeOrigin, size: inputCode.size()).insetBy(dx: -18, dy: -16)
        let selection = NSRect(x: target.minX, y: target.minY, width: max(1, target.width * progress), height: max(1, target.height * progress))
        let shade = NSBezierPath(rect: NSRect(x: 0, y: 0, width: demoWidth, height: demoHeight))
        shade.append(NSBezierPath(rect: selection))
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.38).setFill()
        shade.fill()
        NSColor.white.setStroke()
        NSBezierPath(rect: selection.insetBy(dx: 0.5, dy: 0.5)).stroke()
        let corner = NSPoint(x: selection.maxX, y: selection.maxY)
        let cross = NSBezierPath()
        cross.move(to: NSPoint(x: corner.x - 10, y: corner.y)); cross.line(to: NSPoint(x: corner.x + 10, y: corner.y))
        cross.move(to: NSPoint(x: corner.x, y: corner.y - 10)); cross.line(to: NSPoint(x: corner.x, y: corner.y + 10))
        cross.lineWidth = 1.5
        cross.stroke()
        let size = "\(Int(selection.width * 2)) × \(Int(selection.height * 2))"
        roundedRect(NSRect(x: corner.x + 10, y: corner.y + 10, width: 86, height: 20), radius: 4, fill: .black.withAlphaComponent(0.6))
        label(size, at: NSPoint(x: corner.x + 16, y: corner.y + 12), size: 11, color: .white)
    }

    // Keyboard shortcut overlay.
    if let keys = scene.keycap {
        let box = NSRect(x: demoWidth / 2 - 90, y: demoHeight - 190, width: 180, height: 64)
        roundedRect(box, radius: 14, fill: NSColor(hex: 0x05070D, alpha: 0.88))
        label(keys, at: NSPoint(x: box.midX, y: box.minY + 13), size: 30, weight: .semibold, color: .white, centered: true)
    }

    // Confirmation under the menu bar.
    if scene.copied {
        let toast = NSRect(x: demoWidth - 300, y: 38, width: 270, height: 42)
        roundedRect(toast, radius: 10, fill: titleBar)
        label("✓", at: NSPoint(x: toast.minX + 16, y: toast.minY + 11), size: 15, weight: .bold, color: good)
        label("Copied \(squintLines.count) lines of code", at: NSPoint(x: toast.minX + 40, y: toast.minY + 12), size: 14, weight: .medium)
    }

    if scene.flash > 0 {
        NSColor.white.withAlphaComponent(scene.flash).setFill()
        NSRect(x: 0, y: 0, width: demoWidth, height: demoHeight).fill()
    }

    // Step captions.
    let steps = ["1   Press ⌘⇧2", "2   Drag over the code", "3   Paste, indentation intact"]
    let pillWidth = 230.0, pillGap = 16.0
    let startX = (demoWidth - (pillWidth * 3 + pillGap * 2)) / 2
    for (index, step) in steps.enumerated() {
        let pill = NSRect(x: startX + Double(index) * (pillWidth + pillGap), y: demoHeight - 76, width: pillWidth, height: 40)
        let active = index + 1 == scene.step
        roundedRect(pill, radius: 20, fill: active ? accent : .white.withAlphaComponent(0.06))
        label(step, at: NSPoint(x: pill.midX, y: pill.minY + 11), size: 15, weight: active ? .semibold : .regular,
              color: active ? .white : dimColor, centered: true)
    }
}

func ease(_ t: Double) -> Double { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }

var frames: [(Scene, Double)] = [(Scene(step: 1), 1.3), (Scene(step: 1, keycap: "⌘ ⇧ 2"), 1.0)]
for index in 0...14 { frames.append((Scene(step: 2, selection: ease(Double(index) / 14)), 0.05)) }
frames += [
    (Scene(step: 2, selection: 1), 0.5),
    (Scene(step: 2, selection: 1, flash: 0.3), 0.06),
    (Scene(step: 2, copied: true), 1.1),
    (Scene(step: 3, keycap: "⌘ V", editor: true), 0.9),
    (Scene(step: 3, editor: true, pasted: true), 3.6),
]

let gifURL = imagesDirectory.appending(path: "demo.gif")
let gif = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for (index, (scene, delay)) in frames.enumerated() {
    let frame = canvas(width: demoWidth, height: demoHeight, scale: 1) { drawScene(scene) }
    CGImageDestinationAddImage(gif, frame, [kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay,
    ]] as CFDictionary)
    savePNG(frame, to: work.appending(path: "frame-\(index).png")) // for review; not committed
}
precondition(CGImageDestinationFinalize(gif))
print("Wrote \(imagesDirectory.path(percentEncoded: false)) (frames for review in \(work.path(percentEncoded: false)))")
