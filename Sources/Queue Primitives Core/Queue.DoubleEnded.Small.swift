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

public import Buffer_Ring_Inline_Primitives
public import Buffer_Ring_Primitives

extension Queue.DoubleEnded where Element: ~Copyable {

    // MARK: - Small (small-buffer optimization double-ended queue)

    /// Small-buffer optimization double-ended queue.
    ///
    /// `Queue.DoubleEnded.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    /// Element cleanup is handled by `Storage.Inline`'s deinit (inline path)
    /// or `Storage.Heap`'s deinit (spilled path). No workarounds needed.
    // WHY: Category D — structural Sendable workaround; the type is
    // WHY: structurally value-safe but the compiler cannot synthesize
    // WHY: Sendable due to a stored pointer / generic parameter shape.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        @usableFromInline
        package var _buffer: Buffer<Element>.Ring.Small<inlineCapacity>

        /// Creates an empty small double-ended queue.
        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Ring.Small<inlineCapacity>()
        }

        /// Whether the deque is currently using heap storage.
        @inlinable
        public var isSpilled: Bool { _buffer.isSpilled }
    }
}

// MARK: - Sendable

extension Queue.DoubleEnded.Small: Sendable where Element: Sendable {}
