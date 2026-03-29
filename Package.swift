// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tap",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Tap",
            path: "Tap",
            exclude: ["Info.plist", "Tap.entitlements"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "TapTests",
            dependencies: ["Tap"],
            path: "Tests"
        ),
    ]
)
