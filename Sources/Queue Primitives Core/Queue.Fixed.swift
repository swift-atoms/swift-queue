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

extension Queue where Element: ~Copyable {

    /// A fixed-capacity FIFO queue supporting move-only elements.
    ///
    /// `Queue.Fixed` allocates storage upfront and throws on overflow.
    /// Uses ring buffer semantics for O(1) operations. Use this variant when
    /// capacity is known or in contexts requiring predictable memory behavior
    /// (embedded, real-time).
    ///
    /// ## Example
    ///
    /// ```swift
    /// var queue = try Queue<Int>.Bounded(capacity: 10)
    /// try queue.enqueue(1)
    /// try queue.enqueue(2)
    /// queue.dequeue()     // Optional(1)
    /// queue.peek { $0 }   // Optional(2)
    /// ```
    ///
    /// ## Move-Only Support
    ///
    /// Both the queue and its elements can be `~Copyable`:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// var handles = try Queue<FileHandle>.Bounded(capacity: 5)
    /// try handles.enqueue(FileHandle())
    /// ```
    // WHY: Category D — structural Sendable workaround; the type is
    // WHY: structurally value-safe but the compiler cannot synthesize
    // WHY: Sendable due to a stored pointer / generic parameter shape.
    @safe
    public struct Fixed: ~Copyable {
        @usableFromInline
        package var _buffer: Buffer<Element>.Ring.Bounded

        /// The maximum number of elements the queue can hold.
        public let capacity: Index.Count

        /// Creates a queue with the specified capacity.
        ///
        /// - Parameter capacity: Maximum number of elements.
        @inlinable
        public init(capacity: Index.Count) {
            self._buffer = Buffer<Element>.Ring.Bounded(minimumCapacity: capacity)
            self.capacity = capacity
        }

        // Note: No deinit needed - Storage.Heap handles cleanup
    }
}

// MARK: - Conditional Conformances

/// `Queue.Fixed` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Queue.Fixed: Copyable where Element: Copyable {}

/// `Queue.Fixed` is `Sendable` when its elements are `Sendable`.
extension Queue.Fixed: @unchecked Sendable where Element: Sendable {}
