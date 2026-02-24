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
public import Buffer_Linked_Primitives

// MARK: - Properties

extension Queue.Linked.Fixed where Element: ~Copyable {
    /// The current number of elements in the queue.
    @inlinable
    public var count: Index<Element>.Count { _buffer.count }

    /// Whether the queue is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// Whether the queue is at capacity.
    @inlinable
    public var isFull: Bool { _buffer.isFull }
}

// MARK: - Core Operations (~Copyable)

extension Queue.Linked.Fixed where Element: ~Copyable {
    /// Enqueues an element at the back of the queue.
    ///
    /// - Parameter element: The element to enqueue.
    /// - Throws: ``Bounded/Error/overflow`` if the queue is at capacity.
    /// - Complexity: O(1)
    @inlinable
    public mutating func enqueue(_ element: consuming Element) throws(__QueueLinkedBoundedError) {
        guard !isFull else { throw .overflow }
        try! _buffer.insert.back(element)
    }

    /// Dequeues and returns the front element, or nil if empty.
    ///
    /// - Returns: The front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func dequeue() -> Element? {
        _buffer.remove.front()
    }

    /// Removes all elements from the queue.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        _buffer.removeAll()
    }
}

// MARK: - Copy-on-Write (Copyable elements only)

extension Queue.Linked.Fixed where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func _makeUnique() {
        _buffer.ensureUnique()
    }

    /// Enqueues an element at the back of the queue (CoW-aware).
    ///
    /// - Parameter element: The element to enqueue.
    /// - Throws: ``Bounded/Error/overflow`` if the queue is at capacity.
    /// - Complexity: O(1), O(n) if copy triggered
    @inlinable
    public mutating func enqueue(_ element: Element) throws(__QueueLinkedBoundedError) {
        guard !isFull else { throw .overflow }
        _makeUnique()
        try! _buffer.insert.back(element)
    }

    /// Dequeues and returns the front element, or nil if empty (CoW-aware).
    ///
    /// - Returns: The front element, or `nil` if the queue is empty.
    /// - Complexity: O(1), O(n) if copy triggered
    @inlinable
    public mutating func dequeue() -> Element? {
        _makeUnique()
        return _buffer.remove.front()
    }

    /// Removes all elements from the queue (CoW-aware).
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        _makeUnique()
        _buffer.removeAll()
    }
}

// MARK: - Peek

extension Queue.Linked.Fixed where Element: ~Copyable {
    /// Peeks at the front element without removing it.
    ///
    /// Uses a closure to support `~Copyable` elements via borrowing.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the front element.
    /// - Returns: The result of the closure, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek<R>(_ body: (borrowing Element) -> R) -> R? {
        _buffer.peekFront(body)
    }
}

extension Queue.Linked.Fixed {
    /// Returns the front element without removing it, or nil if empty.
    ///
    /// This is a convenience method for `Copyable` elements. For `~Copyable`
    /// elements, use ``peek(_:)`` with a closure.
    ///
    /// - Returns: A copy of the front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek() -> Element? {
        _buffer.first
    }
}

// MARK: - Conditional Drain

extension Queue.Linked.Fixed where Element: Copyable {
    /// Drains elements in FIFO order while the predicate returns true.
    @inlinable
    public mutating func drain(
        while predicate: (borrowing Element) -> Bool,
        _ body: (consuming Element) -> Void
    ) {
        _makeUnique()
        while let element = peek(), predicate(element) {
            body(dequeue()!)
        }
    }
}

// MARK: - ForEach

extension Queue.Linked.Fixed where Element: ~Copyable {
    /// Calls the given closure for each element in the queue.
    ///
    /// Elements are visited from front (oldest) to back (newest).
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        _buffer.forEach(body)
    }
}

// MARK: - Sequence (Copyable elements only)

/// `Queue.Linked.Fixed` conforms to `Sequence` when `Element` is `Copyable`.
///
/// This enables `for-in` loops, `map`, `filter`, and other sequence operations.
/// For `~Copyable` elements, use ``forEach(_:)`` instead.
extension Queue.Linked.Fixed: Swift.Sequence where Element: Copyable {

    /// An iterator over the elements of a bounded linked queue.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var _inner: Buffer<Element>.Linked<1>.Iterator

        @usableFromInline
        init(inner: Buffer<Element>.Linked<1>.Iterator) {
            self._inner = inner
        }

        /// Advances to the next element and returns it, or nil if no next element exists.
        @inlinable
        public mutating func next() -> Element? {
            _inner.next()
        }
    }

    /// Returns an iterator over the elements of the queue.
    ///
    /// Elements are yielded from front (oldest) to back (newest).
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(inner: _buffer.makeIterator())
    }
}

// MARK: - Equatable

extension Queue.Linked.Fixed: Equatable where Element: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._buffer == rhs._buffer
    }
}

// MARK: - Hashable

extension Queue.Linked.Fixed: Hashable where Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        _buffer.hash(into: &hasher)
    }
}

// MARK: - Sendable

extension Queue.Linked.Fixed: @unchecked Sendable where Element: Sendable {}

// MARK: - Error Types

extension Queue.Linked where Element: ~Copyable {
    /// Errors that can occur during linked queue operations.
    public typealias Error = __QueueLinkedError
}

extension Queue.Linked.Fixed where Element: ~Copyable {
    /// Errors that can occur during bounded linked queue operations.
    public typealias Error = __QueueLinkedBoundedError
}
