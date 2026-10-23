// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexNotchNavigator",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodexNotchCore", targets: ["CodexNotchCore"]),
        .executable(name: "CodexNotchNavigator", targets: ["CodexNotchNavigator"]),
        .executable(name: "CodexNotchCoreChecks", targets: ["CodexNotchCoreChecks"]),
    ],
    targets: [
        .target(name: "CodexNotchCore"),
        .executableTarget(
            name: "CodexNotchNavigator",
            dependencies: ["CodexNotchCore"]
        ),
        .executableTarget(
            name: "CodexNotchCoreChecks",
            dependencies: ["CodexNotchCore"]
        ),
        .testTarget(
            name: "CodexNotchCoreTests",
            dependencies: ["CodexNotchCore"]
        ),
    ]
)
