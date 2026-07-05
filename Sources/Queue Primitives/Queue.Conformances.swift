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
public import Sequence_Primitives
public import Store_Protocol_Primitives
public import Buffer_Protocol_Primitives
import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Affine_Primitives_Standard_Library_Integration

// ============================================================================
// MARK: - Iteration
// ============================================================================
//
// Sequenceable (single-pass, consuming) chains through the COLUMN: the direct growable
// ring vends its hand-written scalar iterator. The span-bridged Iterable/Collection
// lattice does NOT apply to the queue family — a wrapped ring vends no single span
// ([MEM-SPAN-004]: a count-bounded span under-covers wrapped layouts), so multipass
// borrowing iteration is `forEach` below. The `Shared` columns and the bounded column
// currently lack a live `Sequenceable` (the bounded ring's was Copyable-substrate-gated
// — vacuous since W2, flagged at the ring leg); they iterate via `forEach`/`drain`.

extension __Queue: Sequenceable where S: Sequenceable & ~Copyable, S.Iterator: Escapable {
    @inlinable
    public consuming func makeIterator() -> S.Iterator {
        take().makeIterator()
    }
}

// MARK: - forEach (multipass borrowing walk over the logical order)

extension __Queue where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol` {
    /// Calls the given closure for each element, front (oldest) to back (newest).
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach(_ body: (borrowing S.Element) -> Void) {
        var slot: Index = .zero
        let end = count.map(Ordinal.init)
        while slot < end {
            body(store[slot])
            slot = slot.successor.saturating()
        }
    }
}
