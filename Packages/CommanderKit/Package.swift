// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CommanderKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CommanderCore", targets: ["CommanderCore"]),
        .library(name: "CommanderFileSystem", targets: ["CommanderFileSystem"]),
    ],
    targets: [
        .target(name: "CommanderCore"),
        .target(name: "CommanderFileSystem", dependencies: ["CommanderCore"]),
        .testTarget(name: "CommanderCoreTests", dependencies: ["CommanderCore"]),
        .testTarget(name: "CommanderFileSystemTests", dependencies: ["CommanderFileSystem"]),
    ],
    swiftLanguageModes: [.v6]
)
