// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TCGSearchIOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "TCGSearchCore",
            targets: ["TCGSearchCore"],
        ),
    ],
    targets: [
        .target(
            name: "TCGSearchCore",
            path: "Sources/TCGSearchCore",
        ),
        .testTarget(
            name: "TCGSearchCoreTests",
            dependencies: ["TCGSearchCore"],
            path: "Tests/TCGSearchCoreTests",
        ),
    ],
)
