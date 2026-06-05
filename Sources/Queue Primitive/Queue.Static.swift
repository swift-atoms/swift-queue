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
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
public import Buffer_Ring_Primitives
public import Buffer_Ring_Inline_Primitives

extension Queue where Element: ~Copyable {

    // MARK: - Static (Fixed-Capacity, Inline Storage)

    /// A fixed-capacity, inline-storage FIFO queue with compile-time capacity.
    ///
    /// `Queue.Static` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter. Uses ring buffer semantics for O(1) operations.
    /// Element cleanup is handled by `Storage.Inline`'s deinit, which
    /// iterates its bitvector and deinitializes all tracked elements.
    /// No workarounds needed at this layer.
    public struct Static<let capacity: Int>: ~Copyable {
        @usableFromInline
        package var _buffer: Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Ring.Inline<capacity>

        /// Creates an empty inline queue.
        @inlinable
        public init() {
            self._buffer = Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Ring.Inline<capacity>()
        }
    }
}

// MARK: - Sendable

extension Queue.Static: @unchecked Sendable where Element: Sendable {}
