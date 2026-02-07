// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "BrowserCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(name: "BrowserCore", targets: ["BrowserCore"])
    ],
    dependencies: [
        .package(path: "../SafariLikeContracts"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.9.1"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "BrowserCore",
            dependencies: [
                .product(name: "SafariLikeContracts", package: "SafariLikeContracts"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections")
            ],
            path: "Sources/BrowserCore"
        ),
        .testTarget(
            name: "BrowserCoreTests",
            dependencies: ["BrowserCore"],
            path: "Tests/BrowserCoreTests"
        )
    ]
)
