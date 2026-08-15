// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TwoCursors",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "TwoCursors", targets: ["TwoCursors"]),
        .executable(name: "TwoCursorsLauncher", targets: ["TwoCursorsLauncher"]),
        .executable(name: "TwoCursorsTests", targets: ["TwoCursorsTests"]),
        .library(name: "TwoCursorsCore", targets: ["TwoCursorsCore"]),
    ],
    targets: [
        .target(
            name: "TwoCursorsCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
            ]
        ),
        .executableTarget(
            name: "TwoCursors",
            dependencies: ["TwoCursorsCore"],
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .executableTarget(
            name: "TwoCursorsLauncher",
            dependencies: ["TwoCursorsCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
        .executableTarget(
            name: "TwoCursorsTests",
            dependencies: ["TwoCursorsCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
    ]
)
