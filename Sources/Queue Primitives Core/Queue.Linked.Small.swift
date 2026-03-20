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

    /// A FIFO queue with small-buffer optimization (SmallVec pattern).
    ///
    /// `Queue.Linked.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var queue = Queue<Int>.Linked.Small<4>()  // Inline up to 4 elements
    /// queue.enqueue(1)  // Inline
    /// queue.enqueue(2)  // Inline
    /// queue.enqueue(3)  // Inline
    /// queue.enqueue(4)  // Inline
    /// queue.enqueue(5)  // Spills to heap
    /// ```
    ///
    /// ## Non-Copyable Container
    ///
    /// `Small` is unconditionally `~Copyable` (move-only) even though it requires
    /// `Copyable` elements. This is because it contains inline storage that requires
    /// careful lifecycle management.
    ///
    /// ## Element Requirement
    ///
    /// This variant requires `Element: Copyable` due to InlineArray limitations.
    /// For ~Copyable elements, use ``Queue/Linked`` or ``Queue/Linked/Bounded`` instead.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        @usableFromInline
        package var _storage: List<Element>.Linked<1>.Small<inlineCapacity>

        /// Creates an empty small linked queue.
        public init() {
            self._storage = List<Element>.Linked<1>.Small<inlineCapacity>()
        }

        /// Whether the queue is currently using heap storage.
        public var isSpilled: Bool { _storage.isSpilled }
    }
}

// Note: Queue.Linked.Small and Queue.Linked.Inline are UNCONDITIONALLY ~Copyable due to deinit requirement
