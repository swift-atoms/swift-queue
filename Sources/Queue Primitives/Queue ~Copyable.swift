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

// The COLUMN-GENERIC surface of the queue: everything expressible through the ring
// discipline's seam (front-anchored: `move(at: .zero)` = O(1) head-advancing dequeue;
// `initialize(at: count)` = back-append; logical subscript) and the count surface
// lives here ONCE, for every column. Semantic mutations call the gate before their
// first write, so the same generic body is copy-on-write-correct on the `Shared`
// columns and free on the move-only columns. Only GROWTH, CONSTRUCTION, and capacity
// ops pin per column (`Queue+Columns.swift`).
public import Queue_Primitive
public import Buffer_Protocol_Primitives
public import Store_Protocol_Primitives
import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Affine_Primitives_Standard_Library_Integration

// ============================================================================
// MARK: - Properties (generic: Buffer.Protocol count + seam capacity)
// ============================================================================

extension __Queue where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol`,
    S.Count == Index_Primitives.Index<S.Element>.Count {
    /// The number of elements in the queue.
    @inlinable
    public var count: Index.Count {
        store.count
    }

    /// Whether the queue is empty.
    @inlinable
    public var isEmpty: Bool { store.isEmpty }

    /// The current capacity of the queue.
    @inlinable
    public var capacity: Index.Count { store.capacity }

    /// The number of additional elements that can be enqueued without growth (or, on
    /// the bounded columns, at all).
    ///
    /// - Complexity: O(1)
    @inlinable
    public var freeCapacity: Index.Count {
        store.capacity.subtract.saturating(store.count)
    }
}

// ============================================================================
// MARK: - Core FIFO Operations (generic: gate + the front-anchored seam)
// ============================================================================

extension __Queue where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol`,
    S.Count == Index_Primitives.Index<S.Element>.Count {
    /// Dequeues and returns the front element, or nil if empty.
    ///
    /// The gate runs FIRST (`prepareForMutation()`), so dequeue is
    /// copy-on-write-correct on the `Shared` columns; the seam's front move advances
    /// the ring head — O(1), no element shifts.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func dequeue() -> S.Element? {
        guard !isEmpty else { return nil }
        store.prepareForMutation()
        return store.move(at: .zero)
    }

    /// Peeks at the front element without removing it.
    ///
    /// Uses a closure to support `~Copyable` elements via borrowing.
    ///
    /// - Returns: The result of the closure, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek<R>(_ body: (borrowing S.Element) -> R) -> R? {
        guard !isEmpty else { return nil }
        return body(store[.zero])
    }

    /// Consumes every element front-to-back, leaving the queue empty.
    ///
    /// The seam's ledger keeps `count` honest mid-drain (each front move decrements
    /// and re-anchors), so the loop terminates when the column reports empty.
    @inlinable
    public mutating func drain(_ body: (consuming S.Element) -> Void) {
        store.prepareForMutation()
        while !isEmpty {
            body(store.move(at: .zero))
        }
    }
}

// ============================================================================
// MARK: - Element Access (generic: the gated logical subscript)
// ============================================================================

extension __Queue where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol`,
    S.Count == Index_Primitives.Index<S.Element>.Count {
    /// Accesses the element at the given typed position (0 = front; positions
    /// re-anchor after a dequeue).
    ///
    /// The mutating access runs the column's semantic mutation gate FIRST, so in-place
    /// writes are copy-on-write-correct on the `Shared` columns.
    ///
    /// - Precondition: `index` must be in `0..<count`.
    @inlinable
    public subscript(_ index: Index) -> S.Element {
        _read {
            precondition(index < count, "Index out of bounds")
            yield store[index]
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            store.prepareForMutation()
            yield &store[index]
        }
    }

    /// Accesses the element at the given position via closure (for ~Copyable elements).
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing S.Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(store[index])
    }
}

extension __Queue where S: ~Copyable, S.Element: Copyable, S: Store.`Protocol` & Buffer.`Protocol`,
    S.Count == Index_Primitives.Index<S.Element>.Count {
    /// Returns the front element by value, or nil if empty.
    @inlinable
    public func peek() -> S.Element? {
        guard !isEmpty else { return nil }
        return store[.zero]
    }

    /// Returns the element at the typed position, or nil if out of bounds.
    @inlinable
    public func element(at index: Index) -> S.Element? {
        guard index < count else { return nil }
        return store[index]
    }
}

// ============================================================================
// MARK: - Cloning (generic on the CoW columns)
// ============================================================================

extension __Queue where S: Copyable, S: Store.`Protocol` {
    /// Returns an independent copy of this queue with its own storage.
    ///
    /// On the `Shared` (CoW) columns the fresh value shares the box with `self` at the
    /// moment of copy, so running the mutation gate on it ALWAYS installs a deep copy —
    /// `clone()` never returns shared storage.
    ///
    /// - Complexity: O(`count`)
    @inlinable
    public borrowing func clone() -> Self {
        var result = copy self
        result.store.prepareForMutation()
        return result
    }
}
