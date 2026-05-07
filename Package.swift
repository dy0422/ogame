// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NativeOGame",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "OGameCore", targets: ["OGameCore"]),
        .library(name: "OGamePersistence", targets: ["OGamePersistence"]),
        .executable(name: "OGameMac", targets: ["OGameMac"])
    ],
    targets: [
        .target(
            name: "OGameCore"
        ),
        .target(
            name: "OGamePersistence",
            dependencies: ["OGameCore"]
        ),
        .executableTarget(
            name: "OGameMac",
            dependencies: ["OGameCore", "OGamePersistence"]
        ),
        .testTarget(
            name: "OGameCoreTests",
            dependencies: ["OGameCore"]
        ),
        .testTarget(
            name: "OGamePersistenceTests",
            dependencies: ["OGameCore", "OGamePersistence"]
        )
    ]
)
