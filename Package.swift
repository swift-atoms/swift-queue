// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-queue-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Queue Primitives",
            targets: ["Queue Primitives"]
        )
    ],
    dependencies: [
        .package(path: "../swift-list-primitives"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-input-primitives"),
        .package(path: "../swift-collection-primitives"),
    ],
    targets: [
        .target(
            name: "Queue Primitives",
            dependencies: [
                .product(name: "List Primitives", package: "swift-list-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        .testTarget(
            name: "Queue Primitives Tests",
            dependencies: ["Queue Primitives"]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety()
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
