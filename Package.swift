// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Stash",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Stash", targets: ["Hatch"])
    ],
    targets: [
        .executableTarget(
            name: "Hatch",
            path: "Sources/Hatch",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
