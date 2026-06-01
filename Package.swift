// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BucketDesk",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BucketDesk", targets: ["BucketDesk"])
    ],
    targets: [
        .executableTarget(
            name: "BucketDesk",
            path: "Sources/BucketDesk"
        )
    ]
)
