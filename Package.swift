// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIUsageBar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "AIUsageBarCore"),
        .executableTarget(name: "AIUsageBar", dependencies: ["AIUsageBarCore"]),
        .testTarget(name: "AIUsageBarCoreTests", dependencies: ["AIUsageBarCore"]),
    ]
)
