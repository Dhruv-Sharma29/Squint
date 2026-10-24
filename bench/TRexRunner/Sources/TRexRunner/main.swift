import Foundation
import ImageIO
import TRexCore
// Runs TRex's own Vision OCR engine with TRex's default settings (en-US, accurate, no auto language detection)
// on every PNG in <images>, writing <id>.trex.txt into <outputs>.
let images = URL(fileURLWithPath: CommandLine.arguments[1]), outputs = URL(fileURLWithPath: CommandLine.arguments[2])
let engine = VisionOCREngine()
for url in try FileManager.default.contentsOfDirectory(at: images, includingPropertiesForKeys: nil).sorted(by: { $0.path < $1.path }) where url.pathExtension == "png" {
    let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(url as CFURL, nil)!, 0, nil)!
    let result = try await engine.recognizeText(in: image, languages: ["en-US"], recognitionLevel: .accurate)
    try result.text.write(to: outputs.appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".trex.txt"), atomically: true, encoding: .utf8)
}
print("done")
