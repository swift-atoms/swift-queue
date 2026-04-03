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
public import Buffer_Linear_Primitives

// Note: Queue.Small is unconditionally ~Copyable (inline storage requires deinit),
// so it cannot conform to Swift.Sequence which requires Copyable.
// It conforms to Sequence.Protocol which supports ~Copyable containers.

// ============================================================================
// MARK: - Iterator
// ============================================================================

extension Queue.Small where Element: Copyable {
    /// Iterator for Queue.Small elements.
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

extension Queue.Small.Iterator: Sendable where Element: Sendable {}

// ============================================================================
// MARK: - Sequence.Protocol Conformance
// ============================================================================

extension Queue.Small: Sequence.`Protocol` where Element: Copyable {
    /// Returns an iterator over the queue elements.
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

// ============================================================================
// MARK: - Sequence.Clearable Conformance
// ============================================================================

extension Queue.Small: Sequence.Clearable where Element: Copyable {
    /// Removes all elements from the queue.
    ///
    /// Resets to inline mode if spilled.
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
    @inlinable
    public mutating func removeAll() {
        clear(keepingCapacity: false)
    }
}

// ============================================================================
// MARK: - Sequence.Drain.Protocol Conformance
// ============================================================================

extension Queue.Small: Sequence.Drain.`Protocol` where Element: Copyable {
    /// Drains all elements in FIFO order, passing each to the closure with ownership.
    ///
    /// After this method returns, the queue is empty but still usable.
    /// Resets to inline mode if spilled.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while let element = dequeue() {
            body(element)
        }
    }
}

// MARK: - Conditional Drain

extension Queue.Small where Element: Copyable {
    /// Drains elements in FIFO order while the predicate returns true.
    @inlinable
    public mutating func drain(
        while predicate: (borrowing Element) -> Bool,
        _ body: (consuming Element) -> Void
    ) {
        while let element = peek(), predicate(element) {
            body(dequeue()!)
        }
    }
}

// ============================================================================
// MARK: - Drain Property Accessor
// ============================================================================

extension Queue.Small where Element: Copyable {
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
