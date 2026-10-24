import CoreGraphics
import CoreText
import Foundation
import os
import Vision

/// Finds colour emoji, which Vision can't read: it skips them, or reads `:` or `*`, and can drop the text after them.
/// Candidates are glyph-sized, shaded or colourful blobs of ink; each is compared with every emoji in Apple Color Emoji
/// and kept only on a close match that no other emoji comes near.
// Measured end to end on 300 rendered lines (12–36 pt, light and dark, 1× and 2×): 76% of emoji found, none wrong or
// invented, and no change to the 142 benchmark code screenshots. Emoji under 20 px are found about half the time.
enum EmojiFinder {
    struct Match {
        let emoji: String
        /// Pixels, origin top-left.
        let rect: CGRect
    }

    private typealias RGB = (Int, Int, Int)

    /// `letters` gives the boxes (pixels, origin top-left) of letters and digits Vision read; asked only once a blob
    /// looks like an emoji.
    static func find(in ink: InkMap, letters: () -> [CGRect]) -> [Match] {
        let w = ink.width, h = ink.height, px = ink.pixels
        let bg = ink.background
        func differs(_ i: Int) -> Bool { abs(Int(px[i]) - bg.0) + abs(Int(px[i + 1]) - bg.1) + abs(Int(px[i + 2]) - bg.2) > 64 }
        var mask = [Bool](repeating: false, count: w * h)
        for i in mask.indices { mask[i] = differs(i * 4) }

        var found: [(match: Match, distance: Double)] = []
        var table: [Entry]?
        var letterBoxes: [CGRect]?
        for rect in candidates(mask, width: w, height: h) {
            guard rect.height >= 8, rect.width / rect.height > 0.6, rect.width / rect.height < 1.6,
                  let shading = shading(rect, mask: mask, ink: ink), shading.fill > 0.15, shading.colour || shading.spread > 0.1
            else { continue }
            // Vision's letter boxes cover whole words. An emoji is as tall as the line; a blob clearly shorter than the
            // word it sits in is part of a letter (a blurred blue `n` matches 👖).
            if letterBoxes == nil { letterBoxes = letters() }
            let word = letterBoxes!.first { $0.contains(CGPoint(x: rect.midX, y: rect.midY)) }
            if let word, rect.height < 0.7 * word.height { continue }
            if table == nil { table = entries(on: bg) }
            // Shortlist by 4 × 4 and then 16 × 16 thumbnails, and decide at 32 × 32, where look-alikes such as 😗 and 😙 differ.
            let tiny = thumbnail(rect, side: 4) { pixel(ink, $0, $1) }
            let small = thumbnail(rect, side: 16) { pixel(ink, $0, $1) }
            let large = thumbnail(rect, side: 32) { pixel(ink, $0, $1) }
            let rough = table!.map { ($0, distance(tiny, $0.tiny)) }.sorted { $0.1 < $1.1 }.prefix(40)
            let shortlist = rough.map { ($0.0, distance(small, $0.0.small)) }.sorted { $0.1 < $1.1 }.prefix(5)
            var best: (emoji: String, distance: Double) = ("", .infinity), second = Double.infinity
            for (entry, _) in shortlist {
                let d = distance(large, entry.large)
                if d < best.distance { second = best.distance; best = (entry.emoji, d) } else if d < second { second = d }
            }
            // Flat or colourless ink, how syntax-highlighted or blurred letters look, needs a much closer match; and a
            // real emoji matches one glyph clearly better than the rest, where a smudge of text matches many about equally.
            let limit = shading.spread < 0.05 || !shading.colour ? 0.12 : 0.27
            guard best.distance < limit, best.distance < 0.12 || best.distance < 0.75 * second else { continue }
            // Where Vision read a letter it's usually text, though Vision reads some emoji as letters (✅ as V): only a very
            // close match overrides it.
            if word != nil, best.distance >= 0.15 { continue }
            found.append((Match(emoji: best.emoji, rect: rect), best.distance))
        }
        // Overlapping matches (a blob and the pieces it was merged from): keep the closest.
        var kept: [Match] = []
        for (match, _) in found.sorted(by: { $0.distance < $1.distance }) where !kept.contains(where: { $0.rect.intersects(match.rect) }) {
            kept.append(match)
        }
        return kept
    }

    /// The image with `##` drawn over each emoji, about the two columns an emoji takes in code. Vision reads `#` reliably
    /// and in place, so the text around an emoji keeps its spacing, and `restoring` swaps them back.
    static func marking(_ matches: [Match], in image: CGImage) -> CGImage? {
        guard let ink = InkMap(image), let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let bg = ink.background
        let height = Double(image.height)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let light = bg.0 + bg.1 + bg.2 > 384
        for match in matches {
            let rect = CGRect(x: match.rect.minX, y: height - match.rect.maxY, width: match.rect.width, height: match.rect.height)
            context.setFillColor(CGColor(red: Double(bg.0) / 255, green: Double(bg.1) / 255, blue: Double(bg.2) / 255, alpha: 1))
            context.fill(rect.insetBy(dx: -1, dy: -1))
            func placeholder(size: Double) -> CTLine {
                CTLineCreateWithAttributedString(NSAttributedString(string: "##", attributes: [
                    .init(kCTFontAttributeName as String): CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil)!,
                    .init(kCTForegroundColorAttributeName as String): CGColor(gray: light ? 0 : 1, alpha: 1),
                ]))
            }
            let natural = CTLineGetBoundsWithOptions(placeholder(size: rect.height * 0.8), .useGlyphPathBounds).width
            let line = placeholder(size: rect.height * 0.8 * min(1, rect.width * 0.9 / max(natural, 1)))
            let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            context.textPosition = CGPoint(x: rect.midX - bounds.midX, y: rect.midY - bounds.midY)
            CTLineDraw(line, context)
        }
        return context.makeImage()
    }

    /// `candidate`'s text with the placeholder Vision read for each emoji swapped back, and the indices of the matches
    /// used. Vision reads `#` as `*` on some themes, so both count; any other `#` or `*` stays, as code has those too.
    /// Vision's spacing around `##` is kept: sized to the emoji, it reads gaps as it would around the emoji.
    /// - Parameter line: the candidate's box, in Vision's normalized coordinates.
    static func restoring(_ matches: [Match], in candidate: VNRecognizedText, line: CGRect, imageSize size: CGSize) -> (text: String, used: Set<Int>) {
        let text = candidate.string
        let characters = Array(text.indices)
        func isPlaceholder(_ i: Int) -> Bool { text[characters[i]] == "#" || text[characters[i]] == "*" }
        var owner: [Int: Int] = [:] // character offset -> match

        // Vision's character boxes cover whole words: inside a short word such as `"##"`, a box shows which emoji the
        // placeholder belongs to.
        for i in characters.indices where isPlaceholder(i) {
            guard let box = try? candidate.boundingBox(for: characters[i]..<text.index(after: characters[i]))?.boundingBox else { continue }
            let center = CGPoint(x: box.midX * size.width, y: (1 - box.midY) * size.height)
            owner[i] = matches.indices.first { matches[$0].rect.insetBy(dx: -matches[$0].rect.width / 2, dy: -matches[$0].rect.height / 2).contains(center) }
        }
        // In a longer word (`##Launch`) its box is the word's, so emoji on this line that no box claimed take the nearest
        // free placeholder, estimating each character's position along the line (monospaced code).
        let pixels = CGRect(x: line.minX * size.width, y: (1 - line.maxY) * size.height, width: line.width * size.width, height: line.height * size.height)
        let step = pixels.width / Double(max(characters.count, 1))
        func x(_ i: Int) -> Double { pixels.minX + (Double(i) + 0.5) * step }
        for match in matches.indices where !owner.values.contains(match) {
            let rect = matches[match].rect
            guard pixels.contains(CGPoint(x: rect.midX, y: rect.midY)), // this line only, not its neighbours
                  let nearest = characters.indices.filter({ isPlaceholder($0) && owner[$0] == nil }).min(by: { abs(x($0) - rect.midX) < abs(x($1) - rect.midX) }),
                  abs(x(nearest) - rect.midX) < 3 * step
            else { continue }
            owner[nearest] = match
            // and the other half of the `##`, on whichever side it is
            if let pair = [nearest - 1, nearest + 1].first(where: { characters.indices.contains($0) && isPlaceholder($0) && owner[$0] == nil }) {
                owner[pair] = match
            }
        }

        var out = ""
        var current: Int? // the emoji the previous placeholder belonged to
        for i in characters.indices {
            guard let match = owner[i] else {
                out.append(text[characters[i]])
                if text[characters[i]] != " " { current = nil }
                continue
            }
            if match == current { // the second `#` of the pair, sometimes read as `# #`
                while out.last == " " { out.removeLast() }
                continue
            }
            out += matches[match].emoji
            current = match
        }
        return (out, Set(owner.values))
    }

    // MARK: - Finding blobs

    /// Glyph-sized boxes of connected ink, plus the merged boxes of glyphs drawn in several pieces (👀, ☃️).
    private static func candidates(_ mask: [Bool], width w: Int, height h: Int) -> [CGRect] {
        // Two-pass connected-component labelling, 8-connected.
        var labels = [Int32](repeating: 0, count: w * h)
        var parent: [Int32] = [0]
        func root(_ label: Int32) -> Int32 {
            var label = label
            while parent[Int(label)] != label { parent[Int(label)] = parent[Int(parent[Int(label)])]; label = parent[Int(label)] }
            return label
        }
        for y in 0..<h {
            for x in 0..<w where mask[y * w + x] {
                var smallest: Int32 = 0
                for (dx, dy) in [(-1, 0), (-1, -1), (0, -1), (1, -1)] {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, nx < w, ny >= 0 else { continue }
                    let label = labels[ny * w + nx]
                    guard label > 0 else { continue }
                    let r = root(label)
                    if smallest == 0 { smallest = r } else if r != smallest { parent[Int(max(r, smallest))] = min(r, smallest); smallest = min(r, smallest) }
                }
                if smallest == 0 {
                    smallest = Int32(parent.count)
                    parent.append(smallest)
                }
                labels[y * w + x] = smallest
            }
        }
        var minX = [Int](repeating: .max, count: parent.count), minY = minX
        var maxX = [Int](repeating: -1, count: parent.count), maxY = maxX
        for y in 0..<h {
            for x in 0..<w where labels[y * w + x] > 0 {
                let r = Int(root(labels[y * w + x]))
                minX[r] = min(minX[r], x); maxX[r] = max(maxX[r], x); minY[r] = min(minY[r], y); maxY[r] = max(maxY[r], y)
            }
        }
        let pieces = parent.indices.filter { maxX[$0] >= 0 }.map {
            CGRect(x: minX[$0], y: minY[$0], width: maxX[$0] - minX[$0] + 1, height: maxY[$0] - minY[$0] + 1)
        }.filter { $0.width * $0.height >= 4 }

        // Merge pieces that touch once grown by 10% of their height, while the result stays glyph-shaped: descenders
        // touching the next line, or letters touching in a word, must not chain into a paragraph-sized box.
        var boxes = pieces
        var changed = true
        while changed {
            changed = false
            var merged: [CGRect] = []
            for box in boxes.sorted(by: { $0.minX < $1.minX }) {
                let grow = max(1, box.height * 0.1)
                // `merged` is in order of left edge, and a mergeable box is at most two of this box's heights wider.
                var target: Int?
                for i in merged.indices.reversed() {
                    let other = merged[i]
                    if other.minX < box.minX - 4 * max(box.height, other.height) { break }
                    let otherGrow = max(1, other.height * 0.1)
                    guard other.insetBy(dx: -otherGrow, dy: -otherGrow).intersects(box.insetBy(dx: -grow, dy: -grow)) else { continue }
                    let union = other.union(box)
                    if union.height <= 1.3 * max(other.height, box.height), union.width <= 2 * union.height { target = i; break }
                }
                if let target {
                    merged[target] = merged[target].union(box)
                    changed = true
                } else {
                    merged.append(box)
                }
            }
            boxes = merged
        }
        // The pieces too: a merge can swallow a neighbour, such as the `"` in `🌍")`.
        return boxes + pieces.filter { $0.height >= 8 && !boxes.contains($0) }
    }

    /// How much of `rect` is ink, whether it's colourful, and how much its colour varies inside the strokes (text
    /// strokes are one flat colour; emoji are shaded). Interior pixels have all eight neighbours inked, so anti-aliased
    /// edges don't count.
    private static func shading(_ rect: CGRect, mask: [Bool], ink: InkMap) -> (fill: Double, colour: Bool, spread: Double)? {
        let w = ink.width, h = ink.height, px = ink.pixels
        var inked = 0, colourful = 0, interior = 0, sum = (0.0, 0.0, 0.0), squares = 0.0
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) where mask[y * w + x] {
                inked += 1
                let i = (y * w + x) * 4
                let r = Double(px[i]) / 255, g = Double(px[i + 1]) / 255, b = Double(px[i + 2]) / 255
                if max(r, g, b) - min(r, g, b) > 60.0 / 255 { colourful += 1 }
                guard x > 0, y > 0, x < w - 1, y < h - 1 else { continue }
                let above = (y - 1) * w + x, row = y * w + x, below = (y + 1) * w + x
                guard mask[above - 1], mask[above], mask[above + 1], mask[row - 1], mask[row + 1],
                      mask[below - 1], mask[below], mask[below + 1]
                else { continue }
                interior += 1
                sum.0 += r; sum.1 += g; sum.2 += b
                squares += r * r + g * g + b * b
            }
        }
        guard inked > 0 else { return nil }
        let n = Double(interior)
        let spread = interior < 4 ? 0 : max(0, squares / n - (sum.0 * sum.0 + sum.1 * sum.1 + sum.2 * sum.2) / (n * n)).squareRoot()
        return (Double(inked) / Double(rect.width * rect.height), Double(colourful) / Double(inked) > 0.2, spread)
    }

    // MARK: - Comparing

    private struct Entry {
        let emoji: String
        let tiny: [UInt8]
        let small: [UInt8]
        let large: [UInt8]
    }

    /// The table for the last background seen: captures from one editor theme share it.
    private static let cache = OSAllocatedUnfairLock<(background: [Int], entries: [Entry])?>(initialState: nil)

    /// Each glyph as it would look on this background: only the part that stands out from it, as thumbnails.
    private static func entries(on bg: RGB) -> [Entry] {
        let key = [bg.0, bg.1, bg.2]
        if let cached = cache.withLock({ $0 }), cached.background == key { return cached.entries }
        let side = EmojiGlyphs.side
        let entries = EmojiGlyphs.all.compactMap { glyph -> Entry? in
            let p = glyph.pixels
            func composite(_ x: Int, _ y: Int) -> RGB {
                let i = (y * side + x) * 4, a = 255 - Int(p[i + 3])
                return (Int(p[i]) + a * bg.0 / 255, Int(p[i + 1]) + a * bg.1 / 255, Int(p[i + 2]) + a * bg.2 / 255)
            }
            var minX = side, minY = side, maxX = -1, maxY = -1
            for y in 0..<side {
                for x in 0..<side {
                    let c = composite(x, y)
                    guard abs(c.0 - bg.0) + abs(c.1 - bg.1) + abs(c.2 - bg.2) > 64 else { continue }
                    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                }
            }
            guard maxX >= 0 else { return nil }
            let rect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
            return Entry(emoji: glyph.emoji, tiny: thumbnail(rect, side: 4, pixel: composite),
                         small: thumbnail(rect, side: 16, pixel: composite), large: thumbnail(rect, side: 32, pixel: composite))
        }
        cache.withLock { $0 = (key, entries) }
        return entries
    }

    /// `rect` averaged down to `side` × `side` RGB.
    private static func thumbnail(_ rect: CGRect, side n: Int, pixel: (Int, Int) -> RGB) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: n * n * 3)
        for cy in 0..<n {
            let y0 = rect.minY + rect.height * Double(cy) / Double(n), y1 = rect.minY + rect.height * Double(cy + 1) / Double(n)
            for cx in 0..<n {
                let x0 = rect.minX + rect.width * Double(cx) / Double(n), x1 = rect.minX + rect.width * Double(cx + 1) / Double(n)
                var sum = (0, 0, 0), count = 0
                for y in Int(y0)..<max(Int(y0) + 1, Int(y1.rounded(.up))) where Double(y) < rect.maxY {
                    for x in Int(x0)..<max(Int(x0) + 1, Int(x1.rounded(.up))) where Double(x) < rect.maxX {
                        let c = pixel(x, y)
                        sum.0 += c.0; sum.1 += c.1; sum.2 += c.2; count += 1
                    }
                }
                let i = (cy * n + cx) * 3
                out[i] = UInt8(min(255, sum.0 / max(count, 1)))
                out[i + 1] = UInt8(min(255, sum.1 / max(count, 1)))
                out[i + 2] = UInt8(min(255, sum.2 / max(count, 1)))
            }
        }
        return out
    }

    /// Root-mean-square colour difference, 0 (same) to about 1.7.
    private static func distance(_ a: [UInt8], _ b: [UInt8]) -> Double {
        var sum = 0
        for i in a.indices { let d = Int(a[i]) - Int(b[i]); sum += d * d }
        return (Double(sum) / Double(a.count / 3)).squareRoot() / 255
    }

    private static func pixel(_ ink: InkMap, _ x: Int, _ y: Int) -> RGB {
        let i = (y * ink.width + x) * 4
        return (Int(ink.pixels[i]), Int(ink.pixels[i + 1]), Int(ink.pixels[i + 2]))
    }
}
