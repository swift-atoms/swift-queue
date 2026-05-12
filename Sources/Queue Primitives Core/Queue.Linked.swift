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

public import Buffer_Linked_Primitives

extension Queue where Element: ~Copyable {

    /// A linked-list based FIFO queue supporting move-only elements.
    ///
    /// `Queue.Linked` uses arena-based linked list storage where nodes are stored
    /// contiguously and reference each other by index. This provides O(1) enqueue
    /// and dequeue with efficient memory locality.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var queue = Queue<Int>.Linked()
    /// queue.enqueue(1)
    /// queue.enqueue(2)
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
    /// var handles = Queue<FileHandle>.Linked()
    /// handles.enqueue(FileHandle())
    /// ```
    ///
    /// ## Copy-on-Write
    ///
    /// When `Element` is `Copyable`, `Queue.Linked` uses copy-on-write semantics:
    /// copies share storage until mutation.
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    @safe
    public struct Linked: ~Copyable {

        @usableFromInline
        package var _buffer: Buffer<Element>.Linked<1>

        /// Creates an empty linked queue.
        @inlinable
        public init() {
            self._buffer = try! .create(capacity: 4)
        }

        /// Creates a queue with reserved capacity.
        ///
        /// - Parameter capacity: Number of elements to reserve space for.
        /// - Throws: ``Linked/Error/invalidCapacity`` if capacity is negative.
        @inlinable
        public init(reservingCapacity capacity: Int) throws(Queue<Element>.Linked.Error) {
            guard capacity >= 0 else {
                throw .invalidCapacity
            }
            self._buffer = try! .create(capacity: Swift.max(capacity, 4))
        }

        // MARK: - Bounded Variant

        /// A fixed-capacity linked-list FIFO queue.
        ///
        /// `Queue.Linked.Fixed` allocates storage upfront and throws on overflow.
        /// Use this variant when capacity is known or in contexts requiring
        /// predictable memory behavior (embedded, real-time).
        ///
        /// ## Example
        ///
        /// ```swift
        /// var queue = try Queue<Int>.Linked.Fixed(capacity: 10)
        /// try queue.enqueue(1)
        /// try queue.enqueue(2)
        /// queue.dequeue()  // Optional(1)
        /// ```
        // SAFETY: Safe by construction — backing storage uses only stdlib
        // SAFETY: safe types; `@safe` documents that this type performs no
        // SAFETY: unsafe operations.
        @safe
        public struct Fixed: ~Copyable {
            @usableFromInline
            package var _buffer: Buffer<Element>.Linked<1>

            /// The maximum number of elements the queue can hold.
            public let capacity: Index_Primitives.Index<Element>.Count

            /// Creates a queue with the specified capacity.
            ///
            /// - Parameter capacity: Maximum number of elements. Must be positive.
            /// - Throws: ``Bounded/Error/invalidCapacity`` if capacity is not positive.
            @inlinable
            public init(capacity: Index_Primitives.Index<Element>.Count) throws(Queue<Element>.Linked.Fixed.Error) {
                guard capacity > .zero else {
                    throw .invalidCapacity
                }
                self._buffer = try! .create(capacity: capacity.retag())
                self.capacity = capacity
            }
        }
    }
}

// MARK: - Conditional Conformances

/// `Queue.Linked` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Queue.Linked: Copyable where Element: Copyable {}

/// `Queue.Linked.Fixed` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Queue.Linked.Fixed: Copyable where Element: Copyable {}
