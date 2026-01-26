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
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-input-primitives"),
        .package(path: "../swift-collection-primitives"),
        .package(path: "../swift-list-primitives"),
        .package(path: "../swift-property-primitives"),
    ],
    targets: [
        // Internal: Core types with ~Copyable support (no Sequence/Collection conformances)
        .target(
            name: "Queue Primitives Core",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "List Primitives", package: "swift-list-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),
        // Internal: Sequence/Collection/Input conformances (Element: Copyable)
        // Separate module to avoid constraint poisoning on Core types
        .target(
            name: "Queue Primitives Sequence",
            dependencies: [
                "Queue Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
            ]
        ),
        // Public: Re-exports Core and Sequence for users
        .target(
            name: "Queue Primitives",
            dependencies: [
                "Queue Primitives Core",
                "Queue Primitives Sequence",
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
