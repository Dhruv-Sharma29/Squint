import AppKit

/// The Squint logo as a monochrome menu bar glyph: viewfinder corners around an eye whose iris holds `</>`.
/// Drawn in code as a template image, so it stays sharp at every scale and takes the menu bar's light or dark tint.
enum MenuBarIcon {
    @MainActor static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: true, drawingHandler: draw)
        image.isTemplate = true
        image.accessibilityDescription = String(localized: "Squint")
        return image
    }()

    private static func draw(_ rect: NSRect) -> Bool {
        // Laid out on an 18-unit grid, then scaled to 16 pt to match the visual size of SF Symbols in the menu bar.
        let grid = NSAffineTransform()
        grid.scale(by: 16.0 / 18.0)
        grid.concat()
        NSColor.black.set()

        stroke(viewfinder(), width: 1.5)
        stroke(eyelid(controlY: 4.6), width: 1.6) // upper lid heavier, like the logo's
        stroke(eyelid(controlY: 13.6), width: 1.2)
        NSBezierPath(ovalIn: NSRect(x: 6.1, y: 6.5, width: 5.8, height: 5.8)).fill()
        NSGraphicsContext.current?.compositingOperation = .clear // cut `</>` out of the iris
        stroke(codeMark(centerX: 9, centerY: 9.4), width: 0.75)
        return true
    }

    private static func viewfinder() -> NSBezierPath {
        let path = NSBezierPath()
        let near = 1.25, far = 18 - near, arm = 4.25
        for (corner, dx, dy) in [(NSPoint(x: near, y: near), 1.0, 1.0), (NSPoint(x: far, y: near), -1.0, 1.0),
                                 (NSPoint(x: far, y: far), -1.0, -1.0), (NSPoint(x: near, y: far), 1.0, -1.0)] {
            path.move(to: NSPoint(x: corner.x, y: corner.y + dy * arm))
            path.line(to: corner)
            path.line(to: NSPoint(x: corner.x + dx * arm, y: corner.y))
        }
        return path
    }

    private static func eyelid(controlY: Double) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 3.2, y: 9.4))
        path.curve(to: NSPoint(x: 14.8, y: 9.4), controlPoint1: NSPoint(x: 6, y: controlY), controlPoint2: NSPoint(x: 12, y: controlY))
        return path
    }

    private static func codeMark(centerX x: Double, centerY y: Double) -> NSBezierPath {
        let path = NSBezierPath()
        for side in [-1.0, 1.0] { // `<` then `>`
            path.move(to: NSPoint(x: x + side * 1.0, y: y - 1.3))
            path.line(to: NSPoint(x: x + side * 2.1, y: y))
            path.line(to: NSPoint(x: x + side * 1.0, y: y + 1.3))
        }
        path.move(to: NSPoint(x: x + 0.45, y: y - 1.6)) // `/`
        path.line(to: NSPoint(x: x - 0.45, y: y + 1.6))
        return path
    }

    private static func stroke(_ path: NSBezierPath, width: Double) {
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
}
