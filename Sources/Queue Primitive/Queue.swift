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

public import Buffer_Primitive
public import Buffer_Ring_Primitive
public import Buffer_Ring_Bounded_Primitive
public import Buffer_Protocol_Primitives
public import Store_Protocol_Primitives
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Shared_Primitive
public import Index_Primitives

// MARK: - Queue (the ADT tier — generic over the COLUMN)

/// A FIFO queue — the semantic ADT over an explicit RING storage COLUMN.
///
/// The ratified two-column design, the queue family's instantiation (ADT-families
/// tranche, 2026-06-10): `Queue` is generic over `S`, and **copyability flows from the
/// column** (S5):
///
/// ```swift
/// Queue<            Buffer<Storage<…System>.Contiguous<FD >>.Ring >          // zero-cost MOVE-ONLY (default)
/// Queue<Shared<Int, Buffer<Storage<…System>.Contiguous<Int>>.Ring>>         // explicit CoW value semantics
/// Queue<            Buffer<Storage<…System>.Contiguous<Job>>.Ring.Bounded>  // fixed-capacity (bounded)
/// Queue<Shared<Int, Buffer<…>.Ring.Bounded>>                                // fixed-capacity CoW
/// ```
///
/// The ring columns implement the FRONT-ANCHORED seam discipline (`Buffer.Ring`'s
/// `Store.`Protocol`` conformance): logical slot 0 is the front, `move(at: .zero)` is
/// the O(1) head-advancing dequeue, and `initialize(at: count)` is the back-append —
/// so the element-generic surface (dequeue, peek, drain, the gated subscript) lives
/// here ONCE for every column; only construction, growth, and capacity ops pin per
/// column. The fixed-capacity story lives entirely in the BOUNDED column (ASK-E:
/// dissolved into the column vocabulary, not rebuilt as a nest).
@frozen
public struct Queue<S: Store.`Protocol` & Buffer.`Protocol` & ~Copyable>: ~Copyable
where S.Count == Index_Primitives.Index<S.Element>.Count {

    /// The ring storage column — a move-only buffer (the default ownership column) or a
    /// `Shared` CoW column. The ADT is a thin FIFO discipline over it; it carries NO
    /// deinit (teardown lives in the leaf's oracle / the shared box's drain).
    @usableFromInline
    package var store: S

    /// Wraps an existing column.
    @inlinable
    public init(store: consuming S) {
        self.store = store
    }

    /// Consumes the queue, yielding its storage column.
    ///
    /// `@inlinable` is enabled by `@frozen` ([API-IMPL-022]): cross-module partial
    /// consumption of a frozen struct is legal, so the unwrap specializes at the
    /// call site.
    @inlinable
    public consuming func take() -> S {
        store
    }
}

// MARK: - Conditional Conformances (co-located per [COPY-FIX-004])

/// The S5 chain: `Queue<Shared<E, B>>` is `Copyable` exactly when `Shared` is — i.e.
/// when the ELEMENT is. The direct (move-only buffer) columns never satisfy this, by design.
extension Queue: Copyable where S: Copyable {}

extension Queue: Sendable where S: Sendable & ~Copyable {}

// MARK: - Column-pinned construction ([MEM-COPY-017]: the split lives in `Shared`'s
// pinned constructor pairs; the `Queue` forms simply pick the column)

extension Queue where S: ~Copyable {
    /// Creates an empty MOVE-ONLY growable queue (the default ownership column).
    @inlinable
    public init<E: ~Copyable>(minimumCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring {
        self.init(store: S(minimumCapacity: minimumCapacity))
    }

    /// Creates an empty MOVE-ONLY fixed-capacity queue (the bounded column).
    @inlinable
    public init<E: ~Copyable>(capacity: Index_Primitives.Index<E>.Count)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded {
        self.init(store: S(minimumCapacity: capacity))
    }

    /// Creates an empty CoW (value-semantic) growable queue on the `Shared` column.
    @inlinable
    public init<E>(minimumCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring> {
        self.init(store: Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring(minimumCapacity: minimumCapacity)
        ))
    }

    /// Creates an empty statically-unique queue of move-only elements on the `Shared`
    /// column (the boxed flavor of the move-only regime — the box's O(1) move).
    @inlinable
    public init<E: ~Copyable>(minimumCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring> {
        self.init(store: Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring(minimumCapacity: minimumCapacity)
        ))
    }

    /// Creates an empty CoW fixed-capacity queue on the `Shared` bounded column.
    @inlinable
    public init<E>(capacity: Index_Primitives.Index<E>.Count)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded> {
        self.init(store: Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded(minimumCapacity: capacity)
        ))
    }

    /// Creates an empty statically-unique fixed-capacity queue of move-only elements
    /// on the `Shared` bounded column.
    @inlinable
    public init<E: ~Copyable>(capacity: Index_Primitives.Index<E>.Count)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded> {
        self.init(store: Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded(minimumCapacity: capacity)
        ))
    }
}
