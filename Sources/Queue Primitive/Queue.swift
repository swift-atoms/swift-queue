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
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Ownership_Shared_Primitive
public import Index_Primitives

// MARK: - Queue (the ADT tier — generic over the COLUMN)

/// A FIFO queue — the semantic ADT over an explicit RING storage COLUMN.
///
/// The ratified two-column design, the queue family's instantiation (ADT-families
/// tranche, 2026-06-10): `Queue` is generic over `S`, and **copyability flows from the
/// column** (S5):
///
/// ```swift
/// __Queue<            Buffer<Storage<…System>.Contiguous<FD >>.Ring >          // zero-cost MOVE-ONLY (default)
/// __Queue<Ownership.Shared<Int, Buffer<Storage<…System>.Contiguous<Int>>.Ring>>         // explicit CoW value semantics
/// __Queue<            Buffer<Storage<…System>.Contiguous<Job>>.Ring.Bounded>  // fixed-capacity (bounded)
/// __Queue<Ownership.Shared<Int, Buffer<…>.Ring.Bounded>>                                // fixed-capacity CoW
/// ```
///
/// The ring columns implement the FRONT-ANCHORED seam discipline (`Buffer.Ring`'s
/// `Store.`Protocol`` conformance): logical slot 0 is the front, `move(at: .zero)` is
/// the O(1) head-advancing dequeue, and `initialize(at: count)` is the back-append —
/// so the element-generic surface (dequeue, peek, drain, the gated subscript) lives
/// here ONCE for every column; only construction, growth, and capacity ops pin per
/// column. The fixed-capacity story lives entirely in the BOUNDED column (ASK-E:
/// dissolved into the column vocabulary, not rebuilt as a nest).
///
/// ## Carrier (hoisted per [API-IMPL-009]/[PKG-NAME-006])
///
/// `__Queue` is the bound-free carrier ([DS-025]): its column parameter `S` is
/// bound `~Copyable` **only**; every capability (observability, the FIFO seam
/// ops, construction/growth) attaches by conditional `@inlinable` extension keyed
/// on the seams the column conforms. The PUBLIC spelling of the family is the
/// front-door aliases — `Queue<E>` (canonical) and `Queue<E>.Bounded` (fixed
/// capacity) — declared in `Queue.FrontDoor.swift` / `Queue.Bounded.swift`
/// ([DS-028]); the hoisted name never appears in consumer signatures.
@_documentation(visibility: public)
@frozen
public struct __Queue<S: ~Copyable>: ~Copyable {

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

/// The S5 chain: `__Queue<Ownership.Shared<E, B>>` is `Copyable` exactly when `Shared` is — i.e.
/// when the ELEMENT is. The direct (move-only buffer) columns never satisfy this, by design.
extension __Queue: Copyable where S: Copyable {}

extension __Queue: Sendable where S: Sendable & ~Copyable {}

// MARK: - Column-pinned construction ([MEM-COPY-017]: the split lives in `Shared`'s
// pinned constructor pairs; the `Queue` forms simply pick the column)

extension __Queue where S: ~Copyable {
    /// Creates an empty MOVE-ONLY growable queue (the default ownership column).
    @inlinable
    public init<E: ~Copyable>(minimumCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring {
        self.init(store: S(minimumCapacity: minimumCapacity))
    }

    /// Creates an empty MOVE-ONLY fixed-capacity queue (the bounded column).
    @inlinable
    public init<E: ~Copyable>(capacity: Index_Primitives.Index<E>.Count)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded {
        self.init(store: S(minimumCapacity: capacity))
    }

    /// Creates an empty CoW (value-semantic) growable queue on the `Shared` column.
    @inlinable
    public init<E>(minimumCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring> {
        self.init(store: Ownership.Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring(minimumCapacity: minimumCapacity)
        ))
    }

    /// Creates an empty statically-unique queue of move-only elements on the `Shared`
    /// column (the boxed flavor of the move-only regime — the box's O(1) move).
    @inlinable
    public init<E: ~Copyable>(minimumCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring> {
        self.init(store: Ownership.Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring(minimumCapacity: minimumCapacity)
        ))
    }

    /// Creates an empty CoW fixed-capacity queue on the `Shared` bounded column.
    @inlinable
    public init<E>(capacity: Index_Primitives.Index<E>.Count)
    where S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded> {
        self.init(store: Ownership.Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded(minimumCapacity: capacity)
        ))
    }

    /// Creates an empty statically-unique fixed-capacity queue of move-only elements
    /// on the `Shared` bounded column.
    @inlinable
    public init<E: ~Copyable>(capacity: Index_Primitives.Index<E>.Count)
    where S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded> {
        self.init(store: Ownership.Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded(minimumCapacity: capacity)
        ))
    }
}
