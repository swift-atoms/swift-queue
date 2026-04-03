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
public import Buffer_Ring_Primitives

// ============================================================================
// MARK: - Iterator
// ============================================================================

extension Queue.Fixed where Element: Copyable {
    /// An iterator over the elements of a fixed-capacity queue.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var _inner: Buffer<Element>.Ring.Bounded.Iterator

        @usableFromInline
        init(_inner: Buffer<Element>.Ring.Bounded.Iterator) {
            self._inner = _inner
        }

        @_lifetime(&self)
        @inlinable
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            _inner.nextSpan(maximumCount: maximumCount)
        }

        @inlinable
        public mutating func next() -> Element? {
            _inner.next()
        }
    }
}

extension Queue.Fixed.Iterator: @unchecked Sendable where Element: Sendable {}

// ============================================================================
// MARK: - Sequence.Protocol Conformance
// ============================================================================

extension Queue.Fixed: Sequence.`Protocol` where Element: Copyable {
    /// Returns an iterator over the elements of the queue.
    ///
    /// Elements are yielded from front (oldest) to back (newest).
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        Iterator(_inner: _buffer.makeIterator())
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// ============================================================================
// MARK: - Swift.Sequence Conformance
// ============================================================================

extension Queue.Fixed: Swift.Sequence where Element: Copyable {}

// ============================================================================
// MARK: - Sequence.Clearable Conformance
// ============================================================================

extension Queue.Fixed: Sequence.Clearable where Element: Copyable {
    /// Removes all elements from the queue.
    ///
    /// The capacity remains unchanged.
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
    @inlinable
    public mutating func removeAll() {
        clear()
    }
}

// ============================================================================
// MARK: - Sequence.Drain.Protocol Conformance
// ============================================================================

extension Queue.Fixed where Element: Copyable {
    /// Drains all elements in FIFO order, passing each to the closure with ownership.
    ///
    /// After this method returns, the queue is empty but still usable.
    /// The capacity remains unchanged.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        makeUnique()
        while let element = dequeue() {
            body(element)
        }
    }
}

// MARK: - Conditional Drain

extension Queue.Fixed where Element: Copyable {
    /// Drains elements in FIFO order while the predicate returns true.
    @inlinable
    public mutating func drain(
        while predicate: (borrowing Element) -> Bool,
        _ body: (consuming Element) -> Void
    ) {
        makeUnique()
        while let element = peek(), predicate(element) {
            body(dequeue()!)
        }
    }
}

// ============================================================================
// MARK: - Drain Property Accessor
// ============================================================================

extension Queue.Fixed where Element: Copyable {
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
