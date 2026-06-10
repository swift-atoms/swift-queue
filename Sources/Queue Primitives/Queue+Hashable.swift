// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Queue_Primitive

// MARK: - Hashable (the S5 chain)

/// Element-keyed hashing chains through the COLUMN (see `Queue+Equatable.swift`):
/// `Shared` hashes count + live elements in logical order, so equal queues hash equal
/// across distinct boxes, capacities, and physical wrap states.
extension Queue: Hashable where S: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        store.hash(into: &hasher)
    }
}
