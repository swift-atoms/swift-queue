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

public import Buffer_Ring_Primitive
public import Buffer_Ring_Primitives
public import Iterable
public import Iterator_Primitive
public import Iterator_Chunk_Primitives

// MARK: - Iterable (multipass, borrowing) — via materialising adapter
//
// The ring-buffer queue has NO single contiguous element span (the ring wraps), so — unlike the
// contiguous containers which vend `Iterator.Chunk` over a `Memory.Contiguous.Protocol` span —
// `Queue` produces its bulk iterator by wrapping the backing ring's hand-written scalar witness
// `Buffer.Ring.Scalar` in `Iterator_Primitive.Iterator.Materializing`, the span-primitive adapter for generator-style
// sequences. The queue therefore does NOT conform `Memory.Contiguous.Protocol` (no element span).
//
// Per-backing divergence from the queue-linked exemplar: `Buffer.Ring.Scalar` is itself the
// `~Copyable` hand-written GR3 scalar witness (demangle-safe, per Buffer.Ring+Sequence.Protocol),
// so Queue binds its iterators DIRECTLY to it rather than re-wrapping it in a redundant
// `Queue.Iterator` (queue-linked wrapped a *Copyable* `Buffer.Linked` iterator).
//
// Both `Iterable` and `Sequenceable` declare `associatedtype Iterator`, which Swift unifies; the
// dual conformer splits the two bindings with `@_implements`. `Iterable.Iterator` binds to the
// materialising bulk iterator here; `Sequenceable.Iterator` binds to the scalar (Queue+Sequenceable.swift).

extension Queue: Iterable where Element: Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Materializing<Buffer<Element>.Ring.Scalar>

    /// Iterable's bulk span witness: wraps the ring's scalar walk in the generator materialise
    /// adapter. Iterates a copy-on-write snapshot of the ring (multipass-safe).
    @inlinable
    @_lifetime(borrow self)
    @_implements(Iterable, makeIterator())
    public borrowing func iterableMakeIterator() -> Iterator_Primitive.Iterator.Materializing<Buffer<Element>.Ring.Scalar> {
        var snapshot = _buffer
        return Iterator_Primitive.Iterator.Materializing(snapshot.makeIterator())
    }
}
