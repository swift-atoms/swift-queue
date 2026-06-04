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
public import Buffer_Ring_Inline_Primitives
public import Buffer_Ring_Small_Primitive

extension Queue where Element: ~Copyable {

    // MARK: - Small (SmallVec-style: inline then spill to heap)

    /// A FIFO queue with small-buffer optimization (SmallVec pattern).
    ///
    /// `Queue.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    /// This provides the performance benefits of inline storage for common cases
    /// while supporting unbounded growth.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var queue = Queue<Int>.Small<4>()  // Inline up to 4 elements
    /// queue.enqueue(1)  // Inline
    /// queue.enqueue(2)  // Inline
    /// queue.enqueue(3)  // Inline
    /// queue.enqueue(4)  // Inline
    /// queue.enqueue(5)  // Spills to heap, moves all elements
    /// ```
    ///
    /// ## Non-Copyable
    ///
    /// `Queue.Small` is unconditionally `~Copyable` (move-only) because it requires
    /// a deinitializer to clean up inline storage.
    /// Element cleanup is handled by `Storage.Inline`'s deinit (inline path)
    /// or `Storage.Heap`'s deinit (spilled path). No workarounds needed.
    // WHY: Category D — structural Sendable workaround; the type is
    // WHY: structurally value-safe but the compiler cannot synthesize
    // WHY: Sendable due to a stored pointer / generic parameter shape.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        @usableFromInline
        package var _buffer: Buffer<Storage<Element>.Heap>.Ring.Small<inlineCapacity>

        /// Creates an empty small queue.
        @inlinable
        public init() {
            self._buffer = Buffer<Storage<Element>.Heap>.Ring.Small<inlineCapacity>()
        }

        /// Whether the queue is currently using heap storage.
        @inlinable
        public var isSpilled: Bool { _buffer.isSpilled }
    }
}

// MARK: - Sendable

extension Queue.Small: @unchecked Sendable where Element: Sendable {}
