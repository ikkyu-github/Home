// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SafariLikeCoreKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "SafariLikeCoreKit", targets: ["SafariLikeCoreKit"])
    ],
    dependencies: [
        .package(path: "../BrowserCore"),
        .package(path: "../SafariLikeContracts"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.9.1"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "SafariLikeCoreKit",
            dependencies: [
                .product(name: "BrowserCore", package: "BrowserCore"),
                .product(name: "SafariLikeContracts", package: "SafariLikeContracts"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections")
            ],
            path: "Sources/SafariLikeCoreKit",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SafariLikeCoreKitTests",
            dependencies: ["SafariLikeCoreKit"],
            path: "Tests/SafariLikeCoreKitTests"
        )
    ]
)
