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
public import Buffer_Ring_Inline_Primitives

// MARK: - Sequenceable witness (consuming makeIterator)
//
// The single-pass consuming scalar iterator — the `Copyable` witness for the cold
// `Sequenceable` conformance (declared in the ops module). A public member in the type module
// per [MOD-036] refined-C: its body names the `@usableFromInline package` storage `_buffer`,
// re-using the backing inline ring's hand-written scalar witness
// `Buffer.Ring.Inline<capacity>.Scalar` (`~Copyable`, demangle-safe — the GR3-irreducible
// witness). `Queue.Static` is unconditionally `~Copyable`, so the consuming `makeIterator()`
// moves `_buffer` out of the consumed queue into the owning Scalar.

extension Queue.Static where Element: Copyable {

    /// Returns a single-pass consuming iterator over the queue's elements, front to back.
    /// Witness for `Sequenceable`.
    @inlinable
    public consuming func makeIterator() -> Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Ring.Inline<capacity>.Scalar {
        _buffer.makeIterator()
    }
}
