// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-queue",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "Queue", targets: ["Queue"]),

        .library(
            name: "Queue Standard Library Integration",
            targets: ["Queue Standard Library Integration"]
        ),

        .library(
            name: "Queue Apple Foundation Integration",
            targets: ["Queue Apple Foundation Integration"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Queue",
            dependencies: []
        ),

        .target(
            name: "Queue Standard Library Integration",
            dependencies: ["Queue"]
        ),

        .target(
            name: "Queue Apple Foundation Integration",
            dependencies: [
                "Queue",
                "Queue Standard Library Integration",
            ]
        ),

        .testTarget(
            name: "Queue Tests",
            dependencies: ["Queue"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
