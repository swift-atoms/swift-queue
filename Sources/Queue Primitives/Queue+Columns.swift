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

// The COLUMN-PINNED surface: growth and capacity-shape operations cannot ride the seam
// (no growth capability there by design), so each op appears once per ratified column.
// The `Shared` forms cross the box through the gate-first scoped accessors
// (`withUnique` / `withUnique(consuming:_:)` — [MEM-OWN-017]: a consuming parameter
// cannot be consumed inside the closure, so enqueued elements thread through as
// consuming closure PARAMETERS). The pins are `where ==` clauses on METHODS
// (mechanic #2; [MEM-COPY-018]: the column's protocol obligations live in `Shared`'s
// declaration bound, which is what lets these pins derive).
public import Queue_Primitive
public import Buffer_Primitive
public import Buffer_Ring_Primitive
public import Buffer_Ring_Bounded_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Shared_Primitive
public import Index_Primitives

// ============================================================================
// MARK: - Enqueue (growable columns: grows; bounded columns: typed-throws on full)
// ============================================================================

extension Queue where S: ~Copyable {
    /// Enqueues an element at the back (direct growable column; grows as needed).
    ///
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func enqueue<E: ~Copyable>(_ element: consuming E)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring {
        store.pushBack(element)
    }

    /// Enqueues an element at the back (`Shared` growable column; uniqueness restored
    /// first — the gate inside `withUnique` no-ops on the statically-unique lane).
    ///
    /// - Complexity: O(1) amortized (O(n) when a copy must be made first)
    @inlinable
    public mutating func enqueue<E: ~Copyable>(_ element: consuming E)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring> {
        store.withUnique(consuming: element) { ring, element in
            ring.pushBack(element)
        }
    }

    /// Enqueues an element at the back (direct bounded column).
    ///
    /// - Throws: `Error.full` when the fixed capacity is exhausted (the rejected
    ///   element is destroyed — the bounded-column contract).
    /// - Complexity: O(1)
    @inlinable
    public mutating func enqueue<E: ~Copyable>(_ element: consuming E) throws(Error)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded {
        guard store.push.back(element) == nil else {
            throw .full
        }
    }

    /// Enqueues an element at the back (`Shared` bounded column; uniqueness restored
    /// first).
    ///
    /// - Throws: `Error.full` when the fixed capacity is exhausted.
    /// - Complexity: O(1)
    @inlinable
    public mutating func enqueue<E: ~Copyable>(_ element: consuming E) throws(Error)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded> {
        let rejected = store.withUnique(consuming: element) { ring, element in
            ring.push.back(element)
        }
        guard rejected == nil else {
            throw .full
        }
    }
}

// ============================================================================
// MARK: - Clear (storage rebinding; the Shared forms DETACH, preserving siblings)
// ============================================================================

extension Queue where S: ~Copyable {
    /// Removes all elements (direct growable column).
    ///
    /// - Parameter keepingCapacity: If `true` (default), slots are retained.
    @inlinable
    public mutating func clear<E: ~Copyable>(keepingCapacity: Bool = true)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring {
        store.removeAll()
        if !keepingCapacity {
            store = S(minimumCapacity: .zero)
        }
    }

    /// Removes all elements (direct bounded column; the fixed capacity always remains).
    @inlinable
    public mutating func clear<E: ~Copyable>()
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded {
        store.remove.all()
    }

    /// Removes all elements (`Shared` growable column).
    ///
    /// Detaches to a fresh box rather than draining in place: sibling values sharing
    /// the old box keep their elements untouched, and no deep copy is ever needed.
    @inlinable
    public mutating func clear<E>(keepingCapacity: Bool = true)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring> {
        let capacity: Index_Primitives.Index<E>.Count = keepingCapacity ? store.capacity : .zero
        self.store = Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring(minimumCapacity: capacity)
        )
    }

    /// Removes all elements (`Shared` bounded column; detaches to a fresh box of the
    /// same fixed capacity).
    @inlinable
    public mutating func clear<E>()
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded> {
        self.store = Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded(minimumCapacity: store.capacity)
        )
    }
}

// ============================================================================
// MARK: - Capacity (growable columns only — bounded capacity is the column's identity)
// ============================================================================

extension Queue where S: ~Copyable {
    /// Reserves capacity for at least the given number of elements (direct column).
    @inlinable
    public mutating func reserve<E: ~Copyable>(_ minimumCapacity: Index_Primitives.Index<E>.Count)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring {
        store.reserveCapacity(minimumCapacity)
    }

    /// Reserves capacity (`Shared` column; uniquely, behind the gate).
    @inlinable
    public mutating func reserve<E: ~Copyable>(_ minimumCapacity: Index_Primitives.Index<E>.Count)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring> {
        store.withUnique { ring in
            ring.reserveCapacity(minimumCapacity)
        }
    }

    /// Reduces capacity to match the current count, linearizing the ring (direct column).
    ///
    /// - Complexity: O(n)
    @inlinable
    public mutating func compact<E: ~Copyable>()
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring {
        store.compact()
    }

    /// Reduces capacity to match the current count (`Shared` column; uniquely).
    ///
    /// - Complexity: O(n)
    @inlinable
    public mutating func compact<E: ~Copyable>()
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring> {
        store.withUnique { ring in
            ring.compact()
        }
    }
}

// ============================================================================
// MARK: - Cloning (direct columns; the generic `clone()` covers the CoW columns)
// ============================================================================

extension Queue where S: ~Copyable {
    /// Returns an independent copy of this queue (direct growable column).
    ///
    /// - Complexity: O(`count`)
    @inlinable
    public func clone<E>() -> Self
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring {
        Self(store: store.clone())
    }

    /// Returns an independent copy of this queue (direct bounded column).
    ///
    /// - Complexity: O(`count`)
    @inlinable
    public func clone<E>() -> Self
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded {
        Self(store: store.clone())
    }
}
