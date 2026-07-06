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
        // MARK: - Namespace + base type
        .library(name: "Queue Primitive", targets: ["Queue Primitive"]),

        // MARK: - Fixed variant: DELETED at the ADT-families reshape (ASK-E, 2026-06-10 —
        // the fixed-capacity story lives in the COLUMN: Queue<Buffer<…>.Ring.Bounded>)

        // MARK: - Small variant ([DS-027].1: own product, NOT umbrella-re-exported)
        .library(name: "Queue Small Primitive", targets: ["Queue Small Primitive"]),

        // MARK: - Umbrella (ops module; [MOD-005])
        .library(name: "Queue Primitives", targets: ["Queue Primitives"]),

        // MARK: - Test Support
        .library(name: "Queue Primitives Test Support", targets: ["Queue Primitives Test Support"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-ring-primitives.git", branch: "main"),
        // swift-memory-small-primitives: for the `Queue Small Primitive` variant target
        // ONLY ([DS-027].1) — `Queue<E>.Small<n>`'s Memory.Small<n> spill leaf.
        .package(url: "https://github.com/swift-primitives/swift-memory-small-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ownership-shared-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-heap-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-allocation-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-sequence-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-span-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ordinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-affine-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-tagged-primitives.git", branch: "main"),
    ],
    targets: [

        // MARK: - Namespace + base type (struct Queue<S>; the ADT over an explicit ring column)
        .target(
            name: "Queue Primitive",
            dependencies: [
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Bounded Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Ownership Shared Primitive", package: "swift-ownership-shared-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Ordinal Primitives Standard Library Integration", package: "swift-ordinal-primitives"),
                .product(name: "Affine Primitives Standard Library Integration", package: "swift-affine-primitives"),
            ]
        ),

        // MARK: - Small type ([DS-027].1: own product, NO umbrella re-export — keeps the
        //         heap-only consumers' closure lean; the Memory.Small<n> leaf dep lands on
        //         THIS target only. The door's ops flow from `__Queue`'s allocation-generic
        //         pins in `Queue Primitives`, so no op code lives here.)
        .target(
            name: "Queue Small Primitive",
            dependencies: [
                "Queue Primitive",
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Small Primitives", package: "swift-memory-small-primitives"),
            ]
        ),

        // MARK: - Base ops + Umbrella ([MOD-005]: re-exports the in-package type module only)
        .target(
            name: "Queue Primitives",
            dependencies: [
                "Queue Primitive",
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Bounded Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Primitives", package: "swift-buffer-ring-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Ownership Shared Primitive", package: "swift-ownership-shared-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Span Protocol Primitives", package: "swift-span-primitives"),
                .product(name: "Ordinal Primitives Standard Library Integration", package: "swift-ordinal-primitives"),
                .product(name: "Affine Primitives Standard Library Integration", package: "swift-affine-primitives"),
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Queue Primitives Test Support",
            dependencies: [
                "Queue Primitives",
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
        .testTarget(
            name: "Queue Primitives Tests",
            dependencies: [
                "Queue Primitives",
                "Queue Small Primitive",
                "Queue Primitives Test Support",
                .product(name: "Memory Small Primitives", package: "swift-memory-small-primitives"),
                .product(name: "Tagged Primitives Standard Library Integration", package: "swift-tagged-primitives"),
                .product(name: "Ordinal Primitives Standard Library Integration", package: "swift-ordinal-primitives"),
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
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
