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

extension Queue.Storage where Element: ~Copyable {

    /// Inline (stack-allocated) storage for small-buffer optimization.
    ///
    /// Provides the same element management API as `Queue.Storage` but for
    /// elements stored inline within a containing struct. Used by `Queue.Small`,
    /// `Queue.Static`, `Queue.DoubleEnded.Static`, and `Queue.DoubleEnded.Small`
    /// for their inline storage needs.
    ///
    /// Unlike `Array.Storage.Inline` which uses linear indexing, this type
    /// is designed for **ring buffer** semantics where elements wrap around
    /// the capacity boundary.
    ///
    /// ## API Symmetry with Queue.Storage
    ///
    /// | Heap (`Queue.Storage`) | Inline (`Queue.Storage.Inline`) |
    /// |------------------------|--------------------------------|
    /// | `_initializeElement(at:to:)` | `initialize(to:at:)` |
    /// | `_moveElement(at:)` | `move(at:)` |
    /// | `_elementsPointer` | `mutableBasePointer()` |
    /// | `deinit` (ring buffer) | `deinitialize(from:count:)` |
    /// | `_moveAllElements(to:)` | `linearize(to:from:count:)` |
    ///
    /// The inline variant requires head position and count to be passed explicitly
    /// since it doesn't store state internally (the containing type manages state).
    @safe
    @usableFromInline
    package struct Inline<let capacity: Int>: ~Copyable {

        /// Raw byte storage (64 bytes per slot).
        @usableFromInline
        package var raw: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Maximum element stride supported (64 bytes).
        @inlinable
        package static var maxStride: Int { 64 }

        // MARK: - Lifecycle

        /// Creates uninitialized inline storage.
        ///
        /// - Precondition: Element stride must not exceed 64 bytes.
        /// - Precondition: Element alignment must not exceed `Int` alignment.
        @inlinable
        package init() {
            precondition(
                MemoryLayout<Element>.stride <= Self.maxStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self.maxStride) bytes)"
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment))"
            )
            self.raw = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
        }
    }
}

extension Queue.Storage.Inline where Element: ~Copyable {
    // MARK: - Element Access (Mutable)

    /// Returns mutable pointer to element at physical index.
    ///
    /// - Parameter index: The physical index of the element (not logical).
    /// - Returns: A mutable pointer to the element.
    /// - Precondition: Index must be in bounds (caller's responsibility).
    @usableFromInline
    @unsafe
    package mutating func pointer(at index: Int) -> UnsafeMutablePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe Swift.withUnsafeMutablePointer(to: &raw) { rawPointer in
            let base = UnsafeMutableRawPointer(rawPointer)
            return unsafe (base + index * stride).assumingMemoryBound(to: Element.self)
        }
    }

    /// Initializes element at the given physical index.
    ///
    /// - Parameters:
    ///   - element: The element to store (consumed).
    ///   - index: The physical index to initialize.
    /// - Precondition: The slot at index must be uninitialized.
    @usableFromInline
    package mutating func initialize(to element: consuming Element, at index: Int) {
        let ptr = unsafe pointer(at: index)
        unsafe ptr.initialize(to: element)
    }

    /// Moves element from the given physical index.
    ///
    /// - Parameter index: The physical index to move from.
    /// - Returns: The moved element.
    /// - Precondition: The slot at index must be initialized.
    /// - Postcondition: The slot at index is deinitialized.
    @usableFromInline
    package mutating func move(at index: Int) -> Element {
        unsafe pointer(at: index).move()
    }

    // MARK: - Element Access (Read-Only)

    /// Returns read-only pointer to element at physical index.
    ///
    /// - Parameter index: The physical index of the element.
    /// - Returns: A read-only pointer to the element.
    /// - Precondition: Index must be in bounds (caller's responsibility).
    @usableFromInline
    @unsafe
    package func read(at index: Int) -> UnsafePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe Swift.withUnsafePointer(to: raw) { rawPointer in
            let base = unsafe UnsafeRawPointer(rawPointer)
            return unsafe (base + index * stride).assumingMemoryBound(to: Element.self)
        }
    }

    // MARK: - Base Pointers

    /// Returns the base pointer for element storage.
    @usableFromInline
    @unsafe
    package func basePointer() -> UnsafePointer<Element> {
        unsafe Swift.withUnsafePointer(to: raw) { rawPointer in
            let base = unsafe UnsafeRawPointer(rawPointer)
            return unsafe base.assumingMemoryBound(to: Element.self)
        }
    }

    /// Returns the mutable base pointer for element storage.
    @usableFromInline
    @unsafe
    package mutating func mutableBasePointer() -> UnsafeMutablePointer<Element> {
        unsafe Swift.withUnsafeMutablePointer(to: &raw) { rawPointer in
            let base = UnsafeMutableRawPointer(rawPointer)
            return unsafe base.assumingMemoryBound(to: Element.self)
        }
    }

    // MARK: - Ring Buffer Bulk Operations

    /// Deinitializes elements in ring buffer order.
    ///
    /// - Parameters:
    ///   - head: The physical index of the first element (head of ring buffer).
    ///   - count: The number of initialized elements.
    /// - Precondition: Elements at ring buffer positions starting from head must be initialized.
    /// - Postcondition: All specified elements are deinitialized.
    /// - Note: Non-mutating to allow use from deinit contexts.
    @usableFromInline
    package func deinitialize(from head: Int, count: Int) {
        guard count > 0 else { return }
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafePointer(to: raw) { rawPointer in
            let base = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(rawPointer))
            for i in 0..<count {
                let physicalIndex = (head + i) % capacity
                unsafe (base + physicalIndex * stride)
                    .assumingMemoryBound(to: Element.self)
                    .deinitialize(count: 1)
            }
        }
    }

    /// Moves all elements to heap storage, linearizing the ring buffer.
    ///
    /// Used when spilling from inline to heap storage. Elements are moved
    /// from ring buffer order to linear order in the heap storage.
    ///
    /// - Parameters:
    ///   - heapStorage: The destination heap storage.
    ///   - head: The physical index of the first element (head of ring buffer).
    ///   - count: The number of initialized elements.
    /// - Precondition: Elements at ring buffer positions starting from head must be initialized.
    /// - Precondition: Heap storage must have sufficient capacity.
    /// - Postcondition: Elements are moved to heap (linearized), inline slots are deinitialized.
    @usableFromInline
    package mutating func linearize(to heapStorage: Queue<Element>.Storage, from head: Int, count: Int) {
        guard count > 0 else { return }
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafePointer(to: raw) { rawPointer in
            unsafe heapStorage.withUnsafeMutablePointerToElements { dst in
                let base = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(rawPointer))
                for dstIndex in 0..<count {
                    let srcIndex = (head + dstIndex) % capacity
                    let src = unsafe (base + srcIndex * stride).assumingMemoryBound(to: Element.self)
                    unsafe (dst + dstIndex).initialize(to: src.move())
                }
            }
        }
    }
}

// MARK: - Copyable Element Extensions

extension Queue.Storage.Inline where Element: Copyable {
    /// Copies all elements to heap storage, linearizing the ring buffer.
    ///
    /// - Parameters:
    ///   - heapStorage: The destination heap storage.
    ///   - head: The physical index of the first element (head of ring buffer).
    ///   - count: The number of initialized elements.
    /// - Precondition: Elements at ring buffer positions starting from head must be initialized.
    /// - Precondition: Heap storage must have sufficient capacity.
    @usableFromInline
    package func copy(to heapStorage: Queue<Element>.Storage, from head: Int, count: Int) {
        guard count > 0 else { return }
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafePointer(to: raw) { rawPointer in
            unsafe heapStorage.withUnsafeMutablePointerToElements { dst in
                let base = unsafe UnsafeRawPointer(rawPointer)
                for dstIndex in 0..<count {
                    let srcIndex = (head + dstIndex) % capacity
                    let src = unsafe (base + srcIndex * stride).assumingMemoryBound(to: Element.self)
                    unsafe (dst + dstIndex).initialize(to: src.pointee)
                }
            }
        }
    }
}
