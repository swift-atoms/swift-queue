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

    // MARK: - Small (small-buffer optimization double-ended queue)

    /// Small-buffer optimization double-ended queue.
    ///
    /// `Queue.DoubleEnded.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
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

        /// Creates an empty small double-ended queue.
        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Ring.Small<inlineCapacity>()
        }

        deinit {
            _buffer._deinitialize()
        }

        /// Whether the deque is currently using heap storage.
        @inlinable
        public var isSpilled: Bool { _buffer.isSpilled }
    }
}

// MARK: - Sendable

extension Queue.DoubleEnded.Small: @unchecked Sendable where Element: Sendable {}
