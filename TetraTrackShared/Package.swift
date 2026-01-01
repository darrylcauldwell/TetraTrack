// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TetraTrackShared",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "TetraTrackShared",
            targets: ["TetraTrackShared"]),
    ],
    targets: [
        .target(
            name: "TetraTrackShared"),
        .testTarget(
            name: "TetraTrackSharedTests",
            dependencies: ["TetraTrackShared"]),
    ]
)
