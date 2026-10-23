// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CommanderKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CommanderCore", targets: ["CommanderCore"]),
        .library(name: "CommanderFileSystem", targets: ["CommanderFileSystem"]),
        .library(name: "CommanderController", targets: ["CommanderController"]),
    ],
    targets: [
        .target(name: "CommanderCore"),
        .target(name: "CommanderFileSystem", dependencies: ["CommanderCore"]),
        .target(name: "CommanderController", dependencies: ["CommanderCore", "CommanderFileSystem"]),
        .testTarget(name: "CommanderCoreTests", dependencies: ["CommanderCore"]),
        .testTarget(name: "CommanderFileSystemTests", dependencies: ["CommanderFileSystem"]),
        .testTarget(
            name: "CommanderControllerTests",
            dependencies: ["CommanderController", "CommanderCore", "CommanderFileSystem"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
