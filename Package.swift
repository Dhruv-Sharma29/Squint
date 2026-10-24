// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Squint",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Squint"),
        .testTarget(name: "SquintTests", dependencies: ["Squint"], exclude: ["Fixtures"]), // read by path
    ]
)
