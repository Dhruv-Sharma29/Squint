import AppKit
import CoreImage.CIFilterBuiltins
import Foundation
import Testing
@testable import Squint

/// Uses a private pasteboard, so running the tests never touches the real clipboard.
struct ClipboardImageTests {
    private let pasteboard = NSPasteboard(name: NSPasteboard.Name("squint-tests-\(UUID().uuidString)"))

    private func pngData() throws -> Data {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("squint".utf8)
        let image = try #require(filter.outputImage)
        return try #require(CIContext().pngRepresentation(of: image, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()))
    }

    @Test func readsImageData() throws {
        defer { pasteboard.releaseGlobally() }
        let png = try pngData()
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)

        let copy = try #require(try ClipboardImage.file(from: pasteboard))
        defer { try? FileManager.default.removeItem(at: copy) }
        #expect(try Data(contentsOf: copy) == png)
    }

    /// Regression: Finder puts the file's icon on the clipboard as TIFF next to the file URL,
    /// and Squint used to read the icon instead of the image.
    @Test func prefersCopiedImageFileOverFinderIcon() throws {
        defer { pasteboard.releaseGlobally() }
        let png = try pngData()
        let original = URL.temporaryDirectory.appending(path: "squint-test-\(UUID().uuidString).png")
        try png.write(to: original)
        defer { try? FileManager.default.removeItem(at: original) }

        pasteboard.clearContents()
        pasteboard.writeObjects([original as NSURL])
        pasteboard.addTypes([.tiff], owner: nil)
        let icon = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8, samplesPerPixel: 4,
                                                 hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        // Optional in some SDKs and not in others; widening it keeps #require warning-free on both.
        let tiff: Data? = icon.tiffRepresentation
        pasteboard.setData(try #require(tiff), forType: .tiff)

        let copy = try #require(try ClipboardImage.file(from: pasteboard))
        defer { try? FileManager.default.removeItem(at: copy) }
        #expect(copy != original)
        #expect(try Data(contentsOf: copy) == png)
        #expect(FileManager.default.fileExists(atPath: original.path(percentEncoded: false))) // the original is never deleted
    }

    @Test func returnsNilWithoutAnImage() throws {
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("just text", forType: .string)
        #expect(try ClipboardImage.file(from: pasteboard) == nil)
    }
}
