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
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives

// MARK: - Queue<E> — the CANONICAL front door ([DS-028])

/// A FIFO queue over the default column: the growable, heap-allocated, move-only
/// ring.
///
/// This is the canonical front-door alias ([DS-028]) — the sanctioned
/// [API-NAME-004] generic-instantiation exception that pins the default column so
/// consumers spell `Queue<Element>`, never the carrier `__Queue` or a full column.
/// The alias fully specializes: conformances, the pinned constructors, and
/// `~Copyable` elements all flow through it with zero forwarding and zero runtime
/// cost.
///
/// ```swift
/// var q = Queue<Int>()          // growable move-only (this alias)
/// var f = Queue<Int>.Bounded()  // fixed-capacity variant (Queue.Bounded.swift)
/// ```
///
/// Variants live behind nested aliases on the family: `Queue<E>.Bounded` is the
/// fixed-capacity column. The `Shared` (CoW) and `Small`/`Inline` allocation
/// variants are consumer-pulled and land as they gain live consumers (the ring's
/// allocation-generic front doors follow the wave-W3 buffer-ring op
/// generalization).
public typealias Queue<E: ~Copyable> =
    __Queue<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring>
