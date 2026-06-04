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
public import Buffer_Ring_Bounded_Primitive
public import Buffer_Ring_Bounded_Primitives

// MARK: - Sequenceable witness (consuming makeIterator)
//
// The single-pass consuming scalar iterator — the `Copyable` witness for the cold
// `Sequenceable` conformance (declared in the ops module). A public member in the type module
// per [MOD-036] refined-C: its body names the `@usableFromInline package` storage `_buffer`,
// re-using the backing bounded ring's hand-written scalar witness `Buffer.Ring.Bounded.Scalar`
// (`~Copyable`, demangle-safe — the GR3-irreducible witness).

extension Queue.Fixed where Element: Copyable {

    /// Returns a single-pass consuming iterator over the queue's elements, front to back.
    /// Witness for `Sequenceable`.
    @inlinable
    public consuming func makeIterator() -> Buffer<Storage<Element>.Heap>.Ring.Bounded.Scalar {
        _buffer.makeIterator()
    }
}
