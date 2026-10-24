// Runs Apple's Live Text engine (VisionKit's ImageAnalyzer, the same analysis behind selecting text in
// images in Preview, Photos and Safari) on every PNG in <images>, writing <id>.livetext.txt to <outputs>.
//
//   swift bench/LiveText.swift bench/data/images bench/data/outputs

import AppKit
import VisionKit

let images = URL(fileURLWithPath: CommandLine.arguments[1])
let outputs = URL(fileURLWithPath: CommandLine.arguments[2])
let analyzer = ImageAnalyzer()
let files = try FileManager.default.contentsOfDirectory(at: images, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "png" }
    .sorted { $0.path < $1.path }
for url in files {
    let analysis = try await analyzer.analyze(NSImage(contentsOf: url)!, orientation: .up, configuration: .init([.text]))
    let output = outputs.appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".livetext.txt")
    try analysis.transcript.write(to: output, atomically: true, encoding: .utf8)
}
print("Live Text: \(files.count) images")
