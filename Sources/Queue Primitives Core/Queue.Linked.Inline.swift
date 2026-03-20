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

extension Queue.Linked where Element: Copyable {

    /// A fixed-capacity, inline-storage FIFO queue with compile-time capacity.
    ///
    /// `Queue.Linked.Inline` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var queue = Queue<Int>.Linked.Inline<8>()
    /// try queue.enqueue(1)
    /// try queue.enqueue(2)
    /// queue.dequeue()  // Optional(1)
    /// ```
    ///
    /// ## Non-Copyable Container
    ///
    /// `Inline` is unconditionally `~Copyable` (move-only) even though it requires
    /// `Copyable` elements. This is because it contains inline storage that requires
    /// careful lifecycle management.
    ///
    /// ## Element Requirement
    ///
    /// This variant requires `Element: Copyable` due to InlineArray limitations.
    /// For ~Copyable elements, use ``Queue/Linked`` or ``Queue/Linked/Bounded`` instead.
    public struct Inline<let capacity: Int>: ~Copyable {
        @usableFromInline
        package var _storage: List<Element>.Linked<1>.Inline<capacity>

        /// Creates an empty inline linked queue.
        public init() {
            self._storage = List<Element>.Linked<1>.Inline<capacity>()
        }
    }
}
