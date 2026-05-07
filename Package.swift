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
        .executable(name: "OGameMac", targets: ["OGameMac"]),
        .executable(name: "OGameCoreTests", targets: ["OGameCoreTests"]),
        .executable(name: "OGamePersistenceTests", targets: ["OGamePersistenceTests"])
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
        .executableTarget(
            name: "OGameCoreTests",
            dependencies: ["OGameCore"],
            path: "Tests/OGameCoreTests"
        ),
        .executableTarget(
            name: "OGamePersistenceTests",
            dependencies: ["OGameCore", "OGamePersistence"],
            path: "Tests/OGamePersistenceTests"
        )
    ]
)
