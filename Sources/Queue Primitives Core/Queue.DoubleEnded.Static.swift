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

extension Queue.DoubleEnded where Element: ~Copyable {

    // MARK: - Static (inline-storage double-ended queue)

    /// Inline-storage double-ended queue with compile-time capacity.
    ///
    /// `Queue.DoubleEnded.Static` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter. Uses ring buffer semantics for O(1) operations at both ends.
    public struct Static<let capacity: Int>: ~Copyable {
        @usableFromInline
        package var _buffer: Buffer<Element>.Ring.Inline<capacity>

        /// Creates an empty inline double-ended queue.
        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Ring.Inline<capacity>()
        }

        deinit {
            // Buffer.Ring.Inline handles element cleanup
        }
    }
}

// MARK: - Sendable

extension Queue.DoubleEnded.Static: @unchecked Sendable where Element: Sendable {}
