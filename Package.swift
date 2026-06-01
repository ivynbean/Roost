// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Hatch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Hatch", targets: ["Hatch"])
    ],
    targets: [
        .executableTarget(
            name: "Hatch",
            path: "Sources/Hatch"
        )
    ]
)
