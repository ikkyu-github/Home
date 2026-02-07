// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SafariLikeContracts",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(name: "SafariLikeContracts", targets: ["SafariLikeContracts"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.9.1"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "SafariLikeContracts",
            path: "Sources/SafariLikeContracts"
        )
    ]
)
