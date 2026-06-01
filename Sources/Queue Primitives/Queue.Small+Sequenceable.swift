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
public import Buffer_Ring_Primitives
public import Buffer_Ring_Small_Primitive
public import Buffer_Ring_Small_Primitives
public import Sequence_Primitives

// MARK: - Sequenceable (single-pass, consuming)
//
// Re-uses the backing small ring's hand-written scalar witness
// `Buffer.Ring.Small<inlineCapacity>.Scalar`. The consuming `makeIterator()` witness is a public
// member in the type module (Queue.Small+Sequenceable.swift) per [MOD-036] refined-C; this
// conformance is thin and splits the `Iterator` associated-type binding from `Iterable`'s via
// `@_implements`. `Queue.Small` is unconditionally `~Copyable`, so it never conformed
// `Swift.Sequence` (which requires `Copyable`); the prior `struct Iterator` + `Sequence.Protocol`
// are dropped to match the exemplar.

extension Queue.Small: Sequenceable where Element: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Buffer<Element>.Ring.Small<inlineCapacity>.Scalar

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}
