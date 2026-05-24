// swift-tools-version: 6.3.1

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
            name: "Queue Primitives Core",
            targets: ["Queue Primitives Core"]
        ),
        .library(
            name: "Queue Dynamic Primitives",
            targets: ["Queue Dynamic Primitives"]
        ),
        .library(
            name: "Queue Fixed Primitives",
            targets: ["Queue Fixed Primitives"]
        ),
        .library(
            name: "Queue Static Primitives",
            targets: ["Queue Static Primitives"]
        ),
        .library(
            name: "Queue Small Primitives",
            targets: ["Queue Small Primitives"]
        ),
        .library(
            name: "Queue Linked Primitives",
            targets: ["Queue Linked Primitives"]
        ),
        .library(
            name: "Queue DoubleEnded Primitives",
            targets: ["Queue DoubleEnded Primitives"]
        ),
        .library(
            name: "Deque Primitives",
            targets: ["Queue DoubleEnded Primitives"]
        ),
        .library(
            name: "Queue Primitives Test Support",
            targets: ["Queue Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-buffer-primitives"),
        .package(path: "../swift-buffer-ring-primitives"),
        .package(path: "../swift-buffer-linear-primitives"),
        .package(path: "../swift-buffer-linked-primitives"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-vector-primitives"),
        .package(path: "../swift-input-primitives"),
        .package(path: "../swift-collection-primitives"),
        .package(path: "../swift-list-primitives"),
        .package(path: "../swift-property-primitives"),
    ],
    targets: [

        // MARK: - Core
        .target(
            name: "Queue Primitives Core",
            dependencies: [
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Primitives", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Bounded Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Inline Primitives", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Small Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                .product(name: "Buffer Linked Primitive", package: "swift-buffer-linked-primitives"),
                .product(name: "Buffer Linked Primitives", package: "swift-buffer-linked-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Vector Primitives", package: "swift-vector-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "List Primitives Core", package: "swift-list-primitives"),
                .product(name: "List Linked Primitives", package: "swift-list-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),

        // MARK: - Dynamic
        .target(
            name: "Queue Dynamic Primitives",
            dependencies: [
                "Queue Primitives Core",
            ]
        ),

        // MARK: - Fixed
        .target(
            name: "Queue Fixed Primitives",
            dependencies: [
                "Queue Primitives Core",
                "Queue Dynamic Primitives",
            ]
        ),

        // MARK: - Static
        .target(
            name: "Queue Static Primitives",
            dependencies: [
                "Queue Primitives Core",
                "Queue Dynamic Primitives",
            ]
        ),

        // MARK: - Small
        .target(
            name: "Queue Small Primitives",
            dependencies: [
                "Queue Primitives Core",
                "Queue Dynamic Primitives",
            ]
        ),

        // MARK: - Linked
        .target(
            name: "Queue Linked Primitives",
            dependencies: [
                "Queue Primitives Core",
            ]
        ),

        // MARK: - DoubleEnded
        .target(
            name: "Queue DoubleEnded Primitives",
            dependencies: [
                "Queue Primitives Core",
            ]
        ),

        // MARK: - Umbrella
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

        // MARK: - Test Support
        .target(
            name: "Queue Primitives Test Support",
            dependencies: [
                "Queue Primitives",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
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
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
