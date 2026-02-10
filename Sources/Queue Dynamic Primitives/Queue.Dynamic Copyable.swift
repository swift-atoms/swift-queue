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

public import Queue_Primitives_Core
public import Buffer_Primitives

// MARK: - Typed Subscript (Copyable, with CoW)

extension Queue where Element: Copyable {
    /// Accesses the element at the given typed index with copy-on-write semantics.
    ///
    /// - Parameter index: The typed index of the element to access (0 = front).
    /// - Precondition: `index.position` must be in `0..<count`.
    @inlinable
    public subscript(index: Index) -> Element {
        _read {
            yield _buffer[index]
        }
        _modify {
            yield &_buffer[index]
        }
    }
}

// MARK: - Copy-on-Write (Copyable elements only)

extension Queue where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        _buffer.ensureUnique()
    }

    /// Enqueues an element at the back of the queue (CoW-aware).
    ///
    /// - Parameter element: The element to enqueue.
    /// - Complexity: O(1) amortized, O(n) if copy triggered
    @inlinable
    public mutating func enqueue(_ element: Element) {
        _buffer.pushBack(element)
    }

    /// Dequeues and returns the front element, or nil if empty (CoW-aware).
    ///
    /// - Returns: The front element, or `nil` if the queue is empty.
    /// - Complexity: O(1), O(n) if copy triggered
    @inlinable
    public mutating func dequeue() -> Element? {
        guard !_buffer.isEmpty else {
            return nil
        }
        return _buffer.popFront()
    }

    /// Removes all elements from the queue (CoW-aware).
    ///
    /// - Parameter keepingCapacity: If `true`, the queue keeps its current capacity.
    ///   If `false`, the storage is released. Default is `true`.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        _buffer.removeAll()

        if !keepingCapacity {
            _buffer = Buffer<Element>.Ring(minimumCapacity: .zero)
        }
    }
}

extension Queue {
    /// Returns the front element without removing it, or nil if empty.
    ///
    /// This is a convenience method for `Copyable` elements. For `~Copyable`
    /// elements, use ``peek(_:)`` with a closure.
    ///
    /// - Returns: A copy of the front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek() -> Element? {
        guard !_buffer.isEmpty else {
            return nil
        }
        return _buffer.peekFront
    }
}

// MARK: - Sequence (Copyable elements only)

/// `Queue` conforms to `Sequence` when `Element` is `Copyable`.
///
/// This enables `for-in` loops, `map`, `filter`, and other sequence operations.
/// For `~Copyable` elements, use ``forEach(_:)`` instead.
extension Queue: Swift.Sequence where Element: Copyable {

    /// An iterator over the elements of a queue.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _buffer: Buffer<Element>.Ring

        @usableFromInline
        var _logicalIndex: Index_Primitives.Index<Element>.Count

        @usableFromInline
        let _count: Index_Primitives.Index<Element>.Count

        @usableFromInline
        init(buffer: Buffer<Element>.Ring) {
            self._buffer = buffer
            self._logicalIndex = .zero
            self._count = buffer.count
        }

        /// Advances to the next element and returns it, or nil if no next element exists.
        @inlinable
        public mutating func next() -> Element? {
            guard _logicalIndex < _count else { return nil }
            let index = _logicalIndex.map(Ordinal.init)
            _logicalIndex += .one
            return _buffer[index]
        }
    }

    /// Returns an iterator over the elements of the queue.
    ///
    /// Elements are yielded from front (oldest) to back (newest).
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(buffer: _buffer)
    }
}

// MARK: - CoW-aware Capacity Management (Copyable elements)

extension Queue where Element: Copyable {
    /// Reduces capacity to match the current count, releasing unused memory (CoW-aware).
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func compact() {
        _buffer.compact()
    }
}
