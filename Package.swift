// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftNotion",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SwiftNotion", targets: ["SwiftNotion"]),
        .library(name: "SwiftNotionCore", targets: ["SwiftNotionCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        // Core Logic (Reusable)
        .target(
            name: "SwiftNotionCore",
            dependencies: []
        ),
        // CLI Tool (Executable)
        .executableTarget(
            name: "SwiftNotion",
            dependencies: [
                "SwiftNotionCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
