// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Roost",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Roost", targets: ["Roost"])
    ],
    targets: [
        .executableTarget(
            name: "Roost",
            path: "Sources/Roost",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "RoostTests",
            dependencies: ["Roost"]
        )
    ]
)
