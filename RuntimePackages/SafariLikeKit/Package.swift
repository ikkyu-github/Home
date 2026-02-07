// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SafariLikeKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "SafariLikeKit", targets: ["SafariLikeKit"]),
        .library(name: "SafariLikeBuiltinPlugins", targets: ["SafariLikeBuiltinPlugins"])
    ],
    dependencies: [
        .package(path: "../BrowserCore"),
        .package(path: "../SafariLikeCoreKit"),
        .package(path: "../SafariLikeUXKit"),
        .package(path: "../SafariLikeContracts"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.9.1"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "SafariLikeBuiltinPlugins",
            dependencies: [
                .product(name: "SafariLikeContracts", package: "SafariLikeContracts")
            ],
            path: "Sources/SafariLikeBuiltinPlugins"
        ),
        .target(
            name: "SafariLikeKit",
            dependencies: [
                .product(name: "BrowserCore", package: "BrowserCore"),
                .product(name: "SafariLikeCoreKit", package: "SafariLikeCoreKit"),
                .product(name: "SafariLikeUXKit", package: "SafariLikeUXKit"),
                .product(name: "SafariLikeContracts", package: "SafariLikeContracts"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections"),
                "SafariLikeBuiltinPlugins"
            ],
            path: "Sources/SafariLikeKit",
            exclude: []
        ),
        .testTarget(
            name: "SafariLikeKitTests",
            dependencies: ["SafariLikeKit"],
            path: "Tests/SafariLikeKitTests"
        )
    ]
)
