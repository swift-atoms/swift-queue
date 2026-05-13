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

public import Buffer_Linear_Primitives
public import Buffer_Ring_Primitives
public import Queue_Primitives_Core

// ============================================================================
// MARK: - Queue.DoubleEnded (Dynamic)
// ============================================================================

// MARK: Subscript

extension Queue.DoubleEnded where Element: Copyable {
    /// Accesses the element at the given index.
    ///
    /// - Parameter index: The index of the element to access (0 = front).
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Queue.Index) -> Element {
        _read {
            yield _buffer[index]
        }
        _modify {
            yield &_buffer[index]
        }
    }
}

// MARK: Sequence.Protocol

extension Queue.DoubleEnded: Sequence.`Protocol` where Element: Copyable {
    /// Returns the count as the underestimated count since we know the exact size.
    ///
    /// This explicit implementation resolves ambiguity between Swift.Sequence
    /// and Sequence.Protocol+Swift.Sequence default implementation.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// MARK: Sequence.Clearable

extension Queue.DoubleEnded: Sequence.Clearable where Element: Copyable {
    /// Removes all elements from the deque.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.Inout` extension.
    @inlinable
    public mutating func removeAll() {
        clear(keepingCapacity: false)
    }
}

// MARK: Sequence.Drain.Protocol

extension Queue.DoubleEnded: Sequence.Drain.`Protocol` where Element: Copyable {
    /// Drains all elements in front-to-back order, passing each to the closure with ownership.
    ///
    /// After this method returns, the deque is empty but still usable.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        makeUnique()
        while let element = pop(from: .front) {
            body(element)
        }
    }
}

// MARK: Conditional Drain

extension Queue.DoubleEnded where Element: Copyable {
    /// Drains elements front-to-back while the predicate returns true.
    @inlinable
    public mutating func drain(
        while predicate: (borrowing Element) -> Bool,
        _ body: (consuming Element) -> Void
    ) {
        makeUnique()
        while let element = peek(at: .front), predicate(element) {
            body(pop(from: .front)!)
        }
    }
}

// MARK: Drain Property Accessor

extension Queue.DoubleEnded where Element: Copyable {
    /// Accessor for drain operations.
    public var drain: Property<Sequence.Drain, Self>.Inout {
        mutating _read {
            yield Property<Sequence.Drain, Self>.Inout(&self)
        }
        mutating _modify {
            var accessor = Property<Sequence.Drain, Self>.Inout(&self)
            yield &accessor
        }
    }
}

// MARK: Collection.Indexed

extension Queue.DoubleEnded: Collection.Indexed where Element: Copyable {
    @inlinable
    public var startIndex: Queue.Index { .zero }

    @inlinable
    public var endIndex: Queue.Index { count.map(Ordinal.init) }

    @inlinable
    public func index(after i: Queue.Index) -> Queue.Index { i.successor.saturating() }
}

// MARK: Collection.Bidirectional

extension Queue.DoubleEnded: Collection.Bidirectional where Element: Copyable {
    @inlinable
    public func index(before i: Queue.Index) -> Queue.Index { try! i.predecessor.exact() }
}

// MARK: Collection.Protocol

extension Queue.DoubleEnded: Collection.`Protocol` where Element: Copyable {}

// MARK: Collection.Access.Random

extension Queue.DoubleEnded: Collection.Access.Random where Element: Copyable {}

// MARK: Swift.Collection Bridges

extension Queue.DoubleEnded: Swift.Collection where Element: Copyable {}
extension Queue.DoubleEnded: Swift.BidirectionalCollection where Element: Copyable {}
extension Queue.DoubleEnded: Swift.RandomAccessCollection where Element: Copyable {}

// ============================================================================
// MARK: - Queue.DoubleEnded.Fixed
// ============================================================================

// MARK: Iterator

extension Queue.DoubleEnded.Fixed where Element: Copyable {
    /// An iterator over the elements of a fixed-capacity double-ended queue.
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

extension Queue.DoubleEnded.Fixed.Iterator: Sendable where Element: Sendable {}

// MARK: Swift.Sequence

extension Queue.DoubleEnded.Fixed: Swift.Sequence where Element: Copyable {
    /// Returns an iterator over the elements of the deque.
    ///
    /// Elements are yielded from front (oldest) to back (newest).
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_inner: _buffer.makeIterator())
    }
}

// MARK: Sequence.Protocol

extension Queue.DoubleEnded.Fixed: Sequence.`Protocol` where Element: Copyable {
    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// MARK: Sequence.Clearable

extension Queue.DoubleEnded.Fixed: Sequence.Clearable where Element: Copyable {
    /// Removes all elements from the deque.
    ///
    /// The capacity remains unchanged.
    @inlinable
    public mutating func removeAll() {
        clear()
    }
}

// MARK: Sequence.Drain.Protocol

extension Queue.DoubleEnded.Fixed where Element: Copyable {
    /// Drains all elements in front-to-back order (CoW-aware).
    ///
    /// Ensures unique storage before draining. Overrides the base (~Copyable)
    /// drain with copy-on-write preparation per [IMPL-025].
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        makeUnique()
        while let element = pop(from: .front) {
            body(element)
        }
    }
}

// MARK: Fixed Conditional Drain (Copyable)

extension Queue.DoubleEnded.Fixed where Element: Copyable {
    /// Drains elements front-to-back while the predicate returns true (CoW-aware).
    @inlinable
    public mutating func drain(
        while predicate: (borrowing Element) -> Bool,
        _ body: (consuming Element) -> Void
    ) {
        makeUnique()
        while let element = peek(at: .front), predicate(element) {
            body(pop(from: .front)!)
        }
    }
}

// MARK: Subscript

extension Queue.DoubleEnded.Fixed where Element: Copyable {
    /// Accesses the element at the given index.
    ///
    /// - Parameter index: The index of the element to access (0 = front).
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Queue.Index) -> Element {
        _read {
            yield _buffer[index]
        }
        _modify {
            yield &_buffer[index]
        }
    }
}

// MARK: Drain Property Accessor

extension Queue.DoubleEnded.Fixed where Element: Copyable {
    /// Accessor for drain operations.
    public var drain: Property<Sequence.Drain, Self>.Inout {
        mutating _read {
            yield Property<Sequence.Drain, Self>.Inout(&self)
        }
        mutating _modify {
            var accessor = Property<Sequence.Drain, Self>.Inout(&self)
            yield &accessor
        }
    }
}

// MARK: Collection.Indexed

extension Queue.DoubleEnded.Fixed: Collection.Indexed where Element: Copyable {
    @inlinable
    public var startIndex: Queue.Index { .zero }

    @inlinable
    public var endIndex: Queue.Index { count.map(Ordinal.init) }

    @inlinable
    public func index(after i: Queue.Index) -> Queue.Index { i.successor.saturating() }
}

// MARK: Collection.Bidirectional

extension Queue.DoubleEnded.Fixed: Collection.Bidirectional where Element: Copyable {
    @inlinable
    public func index(before i: Queue.Index) -> Queue.Index { try! i.predecessor.exact() }
}

// MARK: Collection.Protocol

extension Queue.DoubleEnded.Fixed: Collection.`Protocol` where Element: Copyable {}

// MARK: Collection.Access.Random

extension Queue.DoubleEnded.Fixed: Collection.Access.Random where Element: Copyable {}

// MARK: Swift.Collection Bridges

extension Queue.DoubleEnded.Fixed: Swift.Collection where Element: Copyable {}
extension Queue.DoubleEnded.Fixed: Swift.BidirectionalCollection where Element: Copyable {}
extension Queue.DoubleEnded.Fixed: Swift.RandomAccessCollection where Element: Copyable {}

// ============================================================================
// MARK: - Queue.DoubleEnded.Static
// ============================================================================

// Note: Queue.DoubleEnded.Static is unconditionally ~Copyable (inline storage requires deinit),
// so it cannot conform to Swift.Sequence which requires Copyable.
// It conforms to Sequence.Protocol which supports ~Copyable containers.

// MARK: Iterator

extension Queue.DoubleEnded.Static where Element: Copyable {
    /// Iterator for Queue.DoubleEnded.Static elements.
    ///
    /// Delegates to `Buffer.Linear.Iterator` over a snapshot for safe iteration,
    /// avoiding pointer escape issues with inline storage.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var _inner: Buffer<Element>.Linear.Iterator

        @usableFromInline
        init(_inner: Buffer<Element>.Linear.Iterator) {
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

extension Queue.DoubleEnded.Static.Iterator: Sendable where Element: Sendable {}

// MARK: Sequence.Protocol

extension Queue.DoubleEnded.Static: Sequence.`Protocol` where Element: Copyable {
    /// Returns an iterator over the deque elements.
    ///
    /// Copies elements to a `Buffer.Linear` snapshot for safe iteration,
    /// avoiding pointer escape issues with inline storage.
    /// Elements are yielded from front (oldest) to back (newest).
    ///
    /// - Note: Incurs O(n) copy cost. For performance-critical code, use
    ///   the mutating `forEach` method instead.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        var snapshot = Buffer<Element>.Linear(minimumCapacity: count)
        _buffer.forEach { element in
            snapshot.append(element)
        }
        return Iterator(_inner: snapshot.makeIterator())
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// MARK: Sequence.Clearable

extension Queue.DoubleEnded.Static: Sequence.Clearable where Element: Copyable {
    /// Removes all elements from the deque.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.Inout` extension.
    @inlinable
    public mutating func removeAll() {
        clear()
    }
}

// MARK: Sequence.Drain.Protocol

extension Queue.DoubleEnded.Static: Sequence.Drain.`Protocol` where Element: Copyable {
    /// Drains all elements in front-to-back order, passing each to the closure with ownership.
    ///
    /// After this method returns, the deque is empty but still usable.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while let element = pop(from: .front) {
            body(element)
        }
    }
}

// MARK: Static Conditional Drain

extension Queue.DoubleEnded.Static where Element: Copyable {
    /// Drains elements front-to-back while the predicate returns true.
    @inlinable
    public mutating func drain(
        while predicate: (borrowing Element) -> Bool,
        _ body: (consuming Element) -> Void
    ) {
        while peek(at: .front, predicate) ?? false {
            body(pop(from: .front)!)
        }
    }
}

// MARK: Drain Property Accessor

extension Queue.DoubleEnded.Static where Element: Copyable {
    /// Accessor for drain operations.
    public var drain: Property<Sequence.Drain, Self>.Inout {
        mutating _read {
            yield Property<Sequence.Drain, Self>.Inout(&self)
        }
        mutating _modify {
            var accessor = Property<Sequence.Drain, Self>.Inout(&self)
            yield &accessor
        }
    }
}

// ============================================================================
// MARK: - Queue.DoubleEnded.Small
// ============================================================================

// Note: Queue.DoubleEnded.Small is unconditionally ~Copyable (inline storage requires deinit),
// so it cannot conform to Swift.Sequence which requires Copyable.
// It conforms to Sequence.Protocol which supports ~Copyable containers.

// MARK: Iterator

extension Queue.DoubleEnded.Small where Element: Copyable {
    /// Iterator for Queue.DoubleEnded.Small elements.
    ///
    /// Delegates to `Buffer.Linear.Iterator` over a snapshot for safe iteration,
    /// avoiding pointer escape issues with inline storage.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var _inner: Buffer<Element>.Linear.Iterator

        @usableFromInline
        init(_inner: Buffer<Element>.Linear.Iterator) {
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

extension Queue.DoubleEnded.Small.Iterator: Sendable where Element: Sendable {}

// MARK: Sequence.Protocol

extension Queue.DoubleEnded.Small: Sequence.`Protocol` where Element: Copyable {
    /// Returns an iterator over the deque elements.
    ///
    /// Copies elements to a `Buffer.Linear` snapshot for safe iteration,
    /// avoiding pointer escape issues with inline storage.
    /// Elements are yielded from front (oldest) to back (newest).
    ///
    /// - Note: Incurs O(n) copy cost. For performance-critical code, use
    ///   the mutating `forEach` method instead.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        var snapshot = Buffer<Element>.Linear(minimumCapacity: count)
        _buffer.forEach { element in
            snapshot.append(element)
        }
        return Iterator(_inner: snapshot.makeIterator())
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// MARK: Sequence.Clearable

extension Queue.DoubleEnded.Small: Sequence.Clearable where Element: Copyable {
    /// Removes all elements from the deque.
    ///
    /// Resets to inline mode if spilled.
    /// This enables `.forEach.consuming { }` pattern via `Property.Inout` extension.
    @inlinable
    public mutating func removeAll() {
        clear()
    }
}

// MARK: Sequence.Drain.Protocol

extension Queue.DoubleEnded.Small: Sequence.Drain.`Protocol` where Element: Copyable {
    /// Drains all elements in front-to-back order, passing each to the closure with ownership.
    ///
    /// After this method returns, the deque is empty but still usable.
    /// Resets to inline mode if spilled.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while let element = pop(from: .front) {
            body(element)
        }
    }
}

// MARK: Small Conditional Drain

extension Queue.DoubleEnded.Small where Element: Copyable {
    /// Drains elements front-to-back while the predicate returns true.
    @inlinable
    public mutating func drain(
        while predicate: (borrowing Element) -> Bool,
        _ body: (consuming Element) -> Void
    ) {
        while peek(at: .front, predicate) ?? false {
            body(pop(from: .front)!)
        }
    }
}

// MARK: Drain Property Accessor

extension Queue.DoubleEnded.Small where Element: Copyable {
    /// Accessor for drain operations.
    public var drain: Property<Sequence.Drain, Self>.Inout {
        mutating _read {
            yield Property<Sequence.Drain, Self>.Inout(&self)
        }
        mutating _modify {
            var accessor = Property<Sequence.Drain, Self>.Inout(&self)
            yield &accessor
        }
    }
}
