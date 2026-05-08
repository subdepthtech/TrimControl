// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TrimControl",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TrimControl", targets: ["TrimControl"]),
        .executable(name: "trimcontrol-tool", targets: ["TrimControlTool"]),
    ],
    targets: [
        .target(
            name: "TrimControlCore"
        ),
        .executableTarget(
            name: "TrimControl",
            dependencies: ["TrimControlCore"]
        ),
        .executableTarget(
            name: "TrimControlTool",
            dependencies: ["TrimControlCore"]
        ),
        .testTarget(
            name: "TrimControlCoreTests",
            dependencies: ["TrimControlCore"]
        ),
    ]
)
