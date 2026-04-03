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

    /// Double-ended queue with O(1) amortized operations at both ends.
    ///
    /// Operations and implementation details are in `Queue.DoubleEnded.swift`.
    @safe
    public struct DoubleEnded {

        @usableFromInline
        package var _buffer: Buffer<Element>.Ring

        /// Which end of the deque to operate on.
        public enum Position: Sendable, Equatable {
            case front
            case back
        }

        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Ring(minimumCapacity: .zero)
        }

        @inlinable
        public init(reservingCapacity capacity: Index.Count) {
            self._buffer = Buffer<Element>.Ring(minimumCapacity: capacity)
        }

        // MARK: - Fixed (nested inside DoubleEnded)

        /// Fixed-capacity double-ended queue.
        ///
        /// Accessed as `Queue<E>.DoubleEnded.Fixed` or via the `Deque.Fixed` typealias.
        @safe
        public struct Fixed {
            @usableFromInline
            package var _buffer: Buffer<Element>.Ring.Bounded

            public let capacity: Index.Count

            @inlinable
            public init(capacity: Index.Count) {
                self._buffer = Buffer<Element>.Ring.Bounded(minimumCapacity: capacity)
                self.capacity = capacity
            }
        }

    }
}

// MARK: - Conditional Conformances

/// `Queue.DoubleEnded` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Queue.DoubleEnded: Copyable where Element: Copyable {}

/// `Queue.DoubleEnded.Fixed` is `Copyable` when its elements are `Copyable`.
extension Queue.DoubleEnded.Fixed: Copyable where Element: Copyable {}

// Note: Queue.DoubleEnded.Static and Queue.DoubleEnded.Small are UNCONDITIONALLY ~Copyable due to deinit

// MARK: - Sendable

/// `Queue.DoubleEnded` is `Sendable` when its elements are `Sendable`.
extension Queue.DoubleEnded: @unchecked Sendable where Element: Sendable {}

/// `Queue.DoubleEnded.Fixed` is `Sendable` when its elements are `Sendable`.
extension Queue.DoubleEnded.Fixed: @unchecked Sendable where Element: Sendable {}
