// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TrackRideShared",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "TrackRideShared",
            targets: ["TrackRideShared"]),
    ],
    targets: [
        .target(
            name: "TrackRideShared"),
        .testTarget(
            name: "TrackRideSharedTests",
            dependencies: ["TrackRideShared"]),
    ]
)
