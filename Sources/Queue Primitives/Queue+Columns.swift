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
public import Buffer_Primitive
public import Buffer_Ring_Bounded_Primitive
public import Buffer_Ring_Primitive
public import Index_Primitives
public import Memory_Allocator_Primitive
public import Memory_Allocator_Protocol_Primitives
public import Memory_Heap_Primitives
public import Ownership_Shared_Primitive
public import Queue_Primitive
public import Storage_Contiguous_Primitives

// ============================================================================
// MARK: - Enqueue (growable columns: grows; bounded columns: typed-throws on full)
// ============================================================================

extension __Queue where S: ~Copyable {
    /// Enqueues an element at the back (direct growable column; grows as needed).
    ///
    /// Allocation-generic ([DS-029] form 2, `Resource: Memory.Growable`): one pin serves
    /// the heap column AND the `Small<n>` inline-budget column — the ring's `pushBack` is
    /// itself R-generic (W3.1), so the growth path re-runs the inline→heap spill decision.
    ///
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func enqueue<E: ~Copyable, Resource: Memory.Growable & ~Copyable>(_ element: consuming E)
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Ring {
        store.pushBack(element)
    }

    /// Enqueues an element at the back (`Shared` growable column; uniqueness restored
    /// first — the gate inside `withUnique` no-ops on the statically-unique lane).
    ///
    /// Heap-pinned with the rest of the `Shared` column: its construction rides the
    /// `Memory.Heap`-pinned `Ownership.Shared(_:)` inits (swift-ownership-shared-primitives,
    /// out of W3.2 scope), so the whole `Shared` column stays on heap until that package's
    /// construction generalizes. The direct `Queue<E>.Small<n>` door does not depend on it.
    ///
    /// - Complexity: O(1) amortized (O(n) when a copy must be made first)
    @inlinable
    public mutating func enqueue<E: ~Copyable>(_ element: consuming E)
    where S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring> {
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
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded {
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
    where S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded> {
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

extension __Queue where S: ~Copyable {
    /// Removes all elements (direct growable column).
    ///
    /// Allocation-generic ([DS-029] form 2): `removeAll()` rides the ledgered seam (form 1)
    /// and the `!keepingCapacity` reset rides `S.create` (form 2), so the pin carries the
    /// `Resource` fence.
    ///
    /// - Parameter keepingCapacity: If `true` (default), slots are retained.
    @inlinable
    public mutating func clear<E: ~Copyable, Resource: Memory.Growable & ~Copyable>(keepingCapacity: Bool = true)
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Ring {
        store.removeAll()
        if !keepingCapacity {
            store = S(minimumCapacity: .zero)
        }
    }

    /// Removes all elements (direct bounded column; the fixed capacity always remains).
    @inlinable
    public mutating func clear<E: ~Copyable>()
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded {
        store.remove.all()
    }

    /// Removes all elements (`Shared` growable column).
    ///
    /// Detaches to a fresh box rather than draining in place: sibling values sharing
    /// the old box keep their elements untouched, and no deep copy is ever needed.
    ///
    /// Heap-pinned (rides the `Memory.Heap`-pinned `Ownership.Shared(_:)` construction).
    @inlinable
    public mutating func clear<E>(keepingCapacity: Bool = true)
    where S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring> {
        let capacity: Index_Primitives.Index<E>.Count = keepingCapacity ? store.capacity : .zero
        self.store = Ownership.Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring(minimumCapacity: capacity)
        )
    }

    /// Removes all elements (`Shared` bounded column; detaches to a fresh box of the
    /// same fixed capacity).
    @inlinable
    public mutating func clear<E>()
    where S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded> {
        self.store = Ownership.Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded(minimumCapacity: store.capacity)
        )
    }
}

// ============================================================================
// MARK: - Capacity (growable columns only — bounded capacity is the column's identity)
// ============================================================================

extension __Queue where S: ~Copyable {
    /// Reserves capacity for at least the given number of elements (direct column).
    ///
    /// Allocation-generic ([DS-029] form 2).
    @inlinable
    public mutating func reserve<E: ~Copyable, Resource: Memory.Growable & ~Copyable>(_ minimumCapacity: Index_Primitives.Index<E>.Count)
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Ring {
        store.reserveCapacity(minimumCapacity)
    }

    /// Reserves capacity (`Shared` column; uniquely, behind the gate).
    ///
    /// Heap-pinned with the rest of the `Shared` column (see the `Shared` enqueue above).
    @inlinable
    public mutating func reserve<E: ~Copyable>(_ minimumCapacity: Index_Primitives.Index<E>.Count)
    where S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring> {
        store.withUnique { ring in
            ring.reserveCapacity(minimumCapacity)
        }
    }

    /// Reduces capacity to match the current count, linearizing the ring (direct column).
    ///
    /// Allocation-generic ([DS-029] form 2).
    ///
    /// - Complexity: O(n)
    @inlinable
    public mutating func compact<E: ~Copyable, Resource: Memory.Growable & ~Copyable>()
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Ring {
        store.compact()
    }

    /// Reduces capacity to match the current count (`Shared` column; uniquely).
    ///
    /// Heap-pinned with the rest of the `Shared` column (see the `Shared` enqueue above).
    ///
    /// - Complexity: O(n)
    @inlinable
    public mutating func compact<E: ~Copyable>()
    where S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring> {
        store.withUnique { ring in
            ring.compact()
        }
    }
}

// ============================================================================
// MARK: - Cloning (direct columns; the generic `clone()` covers the CoW columns)
// ============================================================================

extension __Queue where S: ~Copyable {
    /// Returns an independent copy of this queue (direct growable column).
    ///
    /// Allocation-generic ([DS-029] form 2; `store.clone()` requires `Element: Copyable`,
    /// already implied by the copyable-only `E`).
    ///
    /// - Complexity: O(`count`)
    @inlinable
    public func clone<E, Resource: Memory.Growable & ~Copyable>() -> Self
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Ring {
        Self(store: store.clone())
    }

    /// Returns an independent copy of this queue (direct bounded column).
    ///
    /// - Complexity: O(`count`)
    @inlinable
    public func clone<E>() -> Self
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded {
        Self(store: store.clone())
    }
}
