// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tap",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Tap",
            path: "Tap",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "TapTests",
            dependencies: ["Tap"],
            path: "Tests"
        ),
    ]
)
