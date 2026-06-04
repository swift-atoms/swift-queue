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
public import Buffer_Ring_Primitive
public import Buffer_Ring_Primitives
public import Sequence_Primitives

// MARK: - Sequenceable (single-pass, consuming)
//
// Re-uses the backing ring's hand-written scalar witness `Buffer.Ring.Scalar` (single-pass,
// consuming). The consuming `makeIterator()` witness is a public member in the type module
// (Queue+Sequenceable.swift) per [MOD-036] refined-C; this conformance is thin and splits the
// `Iterator` associated-type binding from `Iterable`'s via `@_implements`.
//
// `Queue` does not conform to `Swift.Sequence`: the span-primitive iteration family is
// `~Copyable, ~Escapable` end-to-end and cannot back a Copyable stdlib `IteratorProtocol` without
// re-introducing a per-type Copyable iterator. This is the DEFERRED `Swift.Sequence`-interop axis
// settled ecosystem-wide — see set-ordered-capability-composition.md §2.8 / §3 (one generic
// `Swift.Sequence` bridge `where Element: Copyable`, vended once). The dropped per-type
// `Swift.Sequence` conformance is a deliberate consumer-facing removal to match the exemplar.

extension Queue: Sequenceable where Element: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Buffer<Storage<Element>.Heap>.Ring.Scalar

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}
