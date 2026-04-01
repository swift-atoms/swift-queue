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

public import Buffer_Primitives

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
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        // WORKAROUND: swiftlang/swift#86652 — @_rawLayout triviality misclassification.
        // Forces compiler to recognize type as non-trivially destructible so deinit executes.
        // COST: 8 bytes overhead per instance.
        // REMOVAL TEST: swift-buffer-primitives/Experiments/rawlayout-access-level-trigger/
        //   Build with `public` access under -O. If it passes, remove this field
        //   and the manual cleanup in deinit.
        // TRACKING: swift-buffer-primitives/Research/rawlayout-release-crash-investigation.md
        //
        // NOTE: Must be declared BEFORE _buffer. The buffer transitively
        // contains @_rawLayout storage which must be last in memory layout.
        // See Storage.Inline for the Swift 6.2.4 IRGen crash details.
        private var _deinitWorkaround: AnyObject? = nil

        @usableFromInline
        package var _buffer: Buffer<Element>.Ring.Small<inlineCapacity>

        /// Creates an empty small queue.
        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Ring.Small<inlineCapacity>()
        }

        deinit {
            _buffer._deinitialize()
        }

        /// Whether the queue is currently using heap storage.
        @inlinable
        public var isSpilled: Bool { _buffer.isSpilled }
    }
}

// MARK: - Sendable

extension Queue.Small: @unchecked Sendable where Element: Sendable {}
