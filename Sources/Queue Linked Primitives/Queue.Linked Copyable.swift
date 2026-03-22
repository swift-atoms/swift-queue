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

// MARK: - Copy-on-Write (Copyable elements only)

extension Queue.Linked where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func _makeUnique() {
        _buffer.ensureUnique()
    }

    /// Enqueues an element at the back of the queue (CoW-aware).
    ///
    /// - Parameter element: The element to enqueue.
    /// - Complexity: O(1) amortized, O(n) if copy triggered
    @inlinable
    public mutating func enqueue(_ element: Element) {
        _makeUnique()
        _ensureCapacityForOneMore()
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
    /// - Parameter keepingCapacity: If `true`, the queue keeps its current capacity.
    ///   If `false`, the storage is released. Default is `true`.
    /// - Complexity: O(n) where n is the number of elements.
    // on removeAll() + conditional buffer reassignment in deep @inlinable chain.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        _makeUnique()
        _buffer.removeAll()
        if !keepingCapacity {
            self._buffer = try! .create(capacity: 4)
        }
    }
}

extension Queue.Linked {
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

// MARK: - Sequence (Copyable elements only)

/// `Queue.Linked` conforms to `Sequence` when `Element` is `Copyable`.
///
/// This enables `for-in` loops, `map`, `filter`, and other sequence operations.
/// For `~Copyable` elements, use ``forEach(_:)`` instead.
extension Queue.Linked: Swift.Sequence where Element: Copyable {

    /// An iterator over the elements of a linked queue.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var _inner: Buffer<Element>.Linked<1>.Iterator

        @usableFromInline
        init(inner: Buffer<Element>.Linked<1>.Iterator) {
            self._inner = inner
        }

        @_lifetime(&self)
        @inlinable
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            _inner.nextSpan(maximumCount: maximumCount)
        }

        @_lifetime(self: immortal)
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

// ============================================================================
// MARK: - Sequence.Protocol Conformance
// ============================================================================

extension Queue.Linked: Sequence.`Protocol` where Element: Copyable {
    /// Returns the count as the underestimated count since we know the exact size.
    ///
    /// This explicit implementation resolves ambiguity between Swift.Sequence
    /// and Sequence.Protocol+Swift.Sequence default implementation.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// ============================================================================
// MARK: - Sequence.Clearable Conformance
// ============================================================================

extension Queue.Linked: Sequence.Clearable where Element: Copyable {
    /// Removes all elements from the queue.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
    @inlinable
    public mutating func removeAll() {
        clear(keepingCapacity: false)
    }
}

// ============================================================================
// MARK: - Sequence.Drain.Protocol Conformance
// ============================================================================

extension Queue.Linked: Sequence.Drain.`Protocol` where Element: Copyable {
    /// Drains all elements in FIFO order, passing each to the closure with ownership.
    ///
    /// After this method returns, the queue is empty but still usable.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        _makeUnique()
        while let element = dequeue() {
            body(element)
        }
    }
}

// MARK: - Conditional Drain

extension Queue.Linked where Element: Copyable {
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

// ============================================================================
// MARK: - Drain Property Accessor
// ============================================================================

extension Queue.Linked where Element: Copyable {
    /// Accessor for drain operations.
    public var drain: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}

// MARK: - Equatable

extension Queue.Linked: Equatable where Element: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._buffer == rhs._buffer
    }
}

// MARK: - Hashable

extension Queue.Linked: Hashable where Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        _buffer.hash(into: &hasher)
    }
}

// MARK: - Sendable

extension Queue.Linked: @unchecked Sendable where Element: Sendable {}
