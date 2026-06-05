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

public import Buffer_Ring_Primitives
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
public import Buffer_Ring_Small_Primitive
public import Buffer_Ring_Small_Primitives
public import Iterable
public import Iterator_Primitive
public import Iterator_Chunk_Primitives

// MARK: - Iterable (multipass, borrowing) — via materialising adapter
//
// `Queue.Small` is unconditionally `~Copyable`: its backing `Buffer.Ring.Small` hybrid inline
// `@_rawLayout` / heap ring storage cannot be copied, so the borrowing `Iterable.makeIterator()`
// cannot build the owning consuming `Scalar` (used by `Sequenceable`). Per-backing divergence from
// the Dynamic exemplar (where `_buffer` is CoW-copyable): the `Iterable` face delegates to the
// small ring's OWN borrow-backed `Iterable` witness — the borrow-backed scalar walker
// `Buffer.Ring.Small.Walk` wrapped in `Iterator.Materializing`. The queue does NOT conform
// `Span.Protocol` (no element span — the ring wraps).
//
// `@_implements` splits the unified `Iterator` associated type: `Iterable.Iterator` binds the
// materialising bulk iterator here; `Sequenceable.Iterator` binds the scalar
// (Queue.Small+Sequenceable.swift).

extension Queue.Small: Iterable where Element: Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Materializing<Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Ring.Small<inlineCapacity>.Walk>

    /// Iterable's bulk span witness: delegates to the small ring's borrow-backed `Iterable`
    /// witness (multipass-safe over the borrowed storage).
    @inlinable
    @_implements(Iterable, makeIterator())
    public borrowing func iterableMakeIterator() -> Iterator_Primitive.Iterator.Materializing<Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Ring.Small<inlineCapacity>.Walk> {
        _buffer.makeIterator()
    }
}
