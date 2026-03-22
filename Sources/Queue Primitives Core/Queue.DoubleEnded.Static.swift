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
        package var _buffer: Buffer<Element>.Ring.Inline<capacity>

        /// Creates an empty inline double-ended queue.
        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Ring.Inline<capacity>()
        }

        deinit {
            // WORKAROUND: Manually clean up elements via the mutating path.
            // WHY: The compiler does not synthesize member destruction for _buffer
            //      (cross-package, value-generic ~Copyable stored property).
            //      Buffer.Ring.Inline's deinit never fires, so we call remove.all()
            //      through a mutable pointer — this uses the mutating codepath
            //      (header+storage deinitialize) which is not affected by the bug.
            // TRACKING: swiftlang/swift #86652 variant
            unsafe withUnsafePointer(to: _buffer) { ptr in
                unsafe UnsafeMutablePointer(mutating: ptr).pointee.remove.all()
            }
        }
    }
}

// MARK: - Sendable

extension Queue.DoubleEnded.Static: @unchecked Sendable where Element: Sendable {}
