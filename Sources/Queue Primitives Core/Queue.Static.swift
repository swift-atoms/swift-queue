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

    // MARK: - Static (Fixed-Capacity, Inline Storage)

    /// A fixed-capacity, inline-storage FIFO queue with compile-time capacity.
    ///
    /// `Queue.Static` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter. Uses ring buffer semantics for O(1) operations.
    public struct Static<let capacity: Int>: ~Copyable {
        @usableFromInline
        package var _buffer: Buffer<Element>.Ring.Inline<capacity>

        // WORKAROUND: Forces compiler to execute deinit body.
        // WHY: Without a reference-typed stored property, the compiler silently
        //      skips the deinit body for ~Copyable structs with cross-package
        //      value-generic stored properties.
        // TRACKING: swiftlang/swift #86652 variant (nested ~Copyable deinit chain)
        // EXPERIMENT: swift-institute/Experiments/noncopyable-nested-deinit-chain/
        // WHEN TO REMOVE: When the compiler correctly destroys ~Copyable structs
        //      with cross-package value-generic stored properties.
        private var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline queue.
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

extension Queue.Static: @unchecked Sendable where Element: Sendable {}
