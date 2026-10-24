// swift-tools-version: 6.1
// Runs TRex's own OCR engine for the benchmark. Expects TRex cloned next to this repository:
//   git clone https://github.com/amebalabs/TRex.git ../TRex   (from the Squint folder's parent)
import PackageDescription

let package = Package(
    name: "TRexRunner",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../../../TRex/Packages/TRexCore")],
    targets: [.executableTarget(name: "TRexRunner", dependencies: [.product(name: "TRexCore", package: "TRexCore")])]
)
