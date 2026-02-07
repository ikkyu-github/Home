// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SafariLikeUIKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "SafariLikeUIKit", targets: ["SafariLikeUIKit"])
    ],
    dependencies: [
        .package(path: "../SafariLikeKit"),
        .package(path: "../SafariLikeCoreKit"),
        .package(path: "../SafariLikeContracts"),
        .package(path: "../BrowserCore"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.9.1"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "SafariLikeUIKit",
            dependencies: [
                .product(name: "SafariLikeKit", package: "SafariLikeKit"),
                .product(name: "SafariLikeCoreKit", package: "SafariLikeCoreKit"),
                .product(name: "SafariLikeContracts", package: "SafariLikeContracts"),
                .product(name: "BrowserCore", package: "BrowserCore")
            ],
            path: "Sources/SafariLikeUIKit"
        ),
        .testTarget(
            name: "SafariLikeUIKitTests",
            dependencies: ["SafariLikeUIKit"],
            path: "Tests/SafariLikeUIKitTests"
        )
    ]
)
