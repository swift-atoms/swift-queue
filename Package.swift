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
        ),
        .library(
            name: "Deque Primitives",
            targets: ["Queue DoubleEnded Primitives"]
        ),
        .library(
            name: "Queue DoubleEnded Primitives",
            targets: ["Queue DoubleEnded Primitives"]
        ),
        .library(
            name: "Queue Primitives Test Support",
            targets: ["Queue Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-buffer-primitives"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-vector-primitives"),
        .package(path: "../swift-input-primitives"),
        .package(path: "../swift-collection-primitives"),
        .package(path: "../swift-list-primitives"),
        .package(path: "../swift-property-primitives"),
    ],
    targets: [
        // Internal: Core types with ~Copyable support (type declarations only)
        .target(
            name: "Queue Primitives Core",
            dependencies: [
                .product(name: "Buffer Primitives", package: "swift-buffer-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Vector Primitives", package: "swift-vector-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "List Primitives", package: "swift-list-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),
        // Per-variant modules: Operations separated from Core types
        .target(
            name: "Queue Dynamic Primitives",
            dependencies: [
                "Queue Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
            ]
        ),
        .target(
            name: "Queue Fixed Primitives",
            dependencies: [
                "Queue Primitives Core",
                "Queue Dynamic Primitives",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
            ]
        ),
        .target(
            name: "Queue Static Primitives",
            dependencies: [
                "Queue Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
            ]
        ),
        .target(
            name: "Queue Small Primitives",
            dependencies: [
                "Queue Primitives Core",
                "Queue Dynamic Primitives",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
            ]
        ),
        .target(
            name: "Queue Linked Primitives",
            dependencies: [
                "Queue Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        .target(
            name: "Queue DoubleEnded Primitives",
            dependencies: [
                "Queue Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        // Public: Re-exports Core and all variant modules for users
        .target(
            name: "Queue Primitives",
            dependencies: [
                "Queue Primitives Core",
                "Queue Dynamic Primitives",
                "Queue Fixed Primitives",
                "Queue Static Primitives",
                "Queue Small Primitives",
                "Queue Linked Primitives",
                "Queue DoubleEnded Primitives",
            ]
        ),
        .target(
            name: "Queue Primitives Test Support",
            dependencies: [
                "Queue Primitives",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Queue Primitives Tests",
            dependencies: [
                "Queue Primitives",
                "Queue Primitives Test Support",
            ]
        )
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
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
