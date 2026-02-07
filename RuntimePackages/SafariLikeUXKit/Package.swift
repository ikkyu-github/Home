// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SafariLikeUXKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(name: "SafariLikeUXKit", targets: ["SafariLikeUXKit"])
    ],
    dependencies: [
        .package(path: "../SafariLikeContracts"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.9.1"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "SafariLikeUXKit",
            dependencies: [
                .product(name: "SafariLikeContracts", package: "SafariLikeContracts")
            ],
            path: "Sources/SafariLikeUXKit"
        ),
        .testTarget(
            name: "SafariLikeUXKitTests",
            dependencies: [
                "SafariLikeUXKit",
                .product(name: "SafariLikeContracts", package: "SafariLikeContracts")
            ],
            path: "Tests/SafariLikeUXKitTests"
        )
    ]
)
