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
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
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

// MARK: Drain Property Accessor

extension Queue.DoubleEnded where Element: Copyable {
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
        let _buffer: Buffer<Element>.Ring.Bounded

        @usableFromInline
        var _logicalIndex: Index_Primitives.Index<Element>.Count

        @usableFromInline
        let _count: Index_Primitives.Index<Element>.Count

        @usableFromInline
        init(buffer: Buffer<Element>.Ring.Bounded) {
            self._buffer = buffer
            self._logicalIndex = .zero
            self._count = buffer.count
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _logicalIndex < _count else { return nil }
            let index = _logicalIndex.map(Ordinal.init)
            _logicalIndex += .one
            return _buffer[index]
        }
    }
}

extension Queue.DoubleEnded.Fixed.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: Swift.Sequence

extension Queue.DoubleEnded.Fixed: Swift.Sequence where Element: Copyable {
    /// Returns an iterator over the elements of the deque.
    ///
    /// Elements are yielded from front (oldest) to back (newest).
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(buffer: _buffer)
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

extension Queue.DoubleEnded.Fixed: Sequence.Drain.`Protocol` where Element: Copyable {
    /// Drains all elements in front-to-back order, passing each to the closure with ownership.
    ///
    /// After this method returns, the deque is empty but still usable.
    /// The capacity remains unchanged.
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
    /// Copies elements to a `Buffer.Linear` snapshot for safe iteration,
    /// avoiding pointer escape issues with inline storage.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        let _buffer: Buffer<Element>.Linear

        @usableFromInline
        let _end: Index_Primitives.Index<Element>.Count

        @usableFromInline
        var _position: Index_Primitives.Index<Element> = .zero

        @usableFromInline
        init(_buffer: Buffer<Element>.Linear) {
            self._buffer = _buffer
            self._end = _buffer.count
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _position < _end else { return nil }
            let element = _buffer[_position]
            _position += .one
            return element
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
        return Iterator(_buffer: snapshot)
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// MARK: Sequence.Clearable

extension Queue.DoubleEnded.Static: Sequence.Clearable where Element: Copyable {
    /// Removes all elements from the deque.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
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

// MARK: Sequence Tag Enums

extension Queue.DoubleEnded.Static where Element: Copyable {
    public enum Drain {
        public typealias View = Property<Sequence.Drain, Queue<Element>.DoubleEnded.Static<capacity>>.View.Typed<Element>.Valued<capacity>
    }
    public enum ForEach {
        public typealias View = Property<Sequence.ForEach, Queue<Element>.DoubleEnded.Static<capacity>>.View.Typed<Element>.Valued<capacity>
    }
    public enum Satisfies {
        public typealias View = Property<Sequence.Satisfies, Queue<Element>.DoubleEnded.Static<capacity>>.View.Typed<Element>.Valued<capacity>
    }
    public enum First {
        public typealias View = Property<Sequence.First, Queue<Element>.DoubleEnded.Static<capacity>>.View.Typed<Element>.Valued<capacity>
    }
    public enum Reduce {
        public typealias View = Property<Sequence.Reduce, Queue<Element>.DoubleEnded.Static<capacity>>.View.Typed<Element>.Valued<capacity>
    }
    public enum Contains {
        public typealias View = Property<Sequence.Contains, Queue<Element>.DoubleEnded.Static<capacity>>.View.Typed<Element>.Valued<capacity>
    }
    public enum Drop {
        public typealias View = Property<Sequence.Drop, Queue<Element>.DoubleEnded.Static<capacity>>.View.Typed<Element>.Valued<capacity>
    }
    public enum Prefix {
        public typealias View = Property<Sequence.Prefix, Queue<Element>.DoubleEnded.Static<capacity>>.View.Typed<Element>.Valued<capacity>
    }
}

// MARK: Property Accessors

extension Queue.DoubleEnded.Static where Element: Copyable {
    /// Accessor for drain operations.
    public var drain: Drain.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Drain.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for forEach operations.
    public var forEach: ForEach.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: ForEach.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for predicate satisfaction checks.
    public var satisfies: Satisfies.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Satisfies.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for finding the first matching element.
    public var first: First.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: First.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for reduce operations.
    public var reduce: Reduce.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Reduce.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for containment checks.
    public var contains: Contains.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Contains.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for drop operations.
    public var drop: Drop.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Drop.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for prefix operations.
    public var prefix: Prefix.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Prefix.View = unsafe .init(&self); yield &view }
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
    /// Copies elements to a `Buffer.Linear` snapshot for safe iteration,
    /// avoiding pointer escape issues with inline storage.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        let _buffer: Buffer<Element>.Linear

        @usableFromInline
        let _end: Index_Primitives.Index<Element>.Count

        @usableFromInline
        var _position: Index_Primitives.Index<Element> = .zero

        @usableFromInline
        init(_buffer: Buffer<Element>.Linear) {
            self._buffer = _buffer
            self._end = _buffer.count
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _position < _end else { return nil }
            let element = _buffer[_position]
            _position += .one
            return element
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
        return Iterator(_buffer: snapshot)
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
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
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

// MARK: Sequence Tag Enums

extension Queue.DoubleEnded.Small where Element: Copyable {
    public enum Drain {
        public typealias View = Property<Sequence.Drain, Queue<Element>.DoubleEnded.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
    public enum ForEach {
        public typealias View = Property<Sequence.ForEach, Queue<Element>.DoubleEnded.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
    public enum Satisfies {
        public typealias View = Property<Sequence.Satisfies, Queue<Element>.DoubleEnded.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
    public enum First {
        public typealias View = Property<Sequence.First, Queue<Element>.DoubleEnded.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
    public enum Reduce {
        public typealias View = Property<Sequence.Reduce, Queue<Element>.DoubleEnded.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
    public enum Contains {
        public typealias View = Property<Sequence.Contains, Queue<Element>.DoubleEnded.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
    public enum Drop {
        public typealias View = Property<Sequence.Drop, Queue<Element>.DoubleEnded.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
    public enum Prefix {
        public typealias View = Property<Sequence.Prefix, Queue<Element>.DoubleEnded.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
}

// MARK: Property Accessors

extension Queue.DoubleEnded.Small where Element: Copyable {
    /// Accessor for drain operations.
    public var drain: Drain.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Drain.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for forEach operations.
    public var forEach: ForEach.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: ForEach.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for predicate satisfaction checks.
    public var satisfies: Satisfies.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Satisfies.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for finding the first matching element.
    public var first: First.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: First.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for reduce operations.
    public var reduce: Reduce.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Reduce.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for containment checks.
    public var contains: Contains.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Contains.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for drop operations.
    public var drop: Drop.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Drop.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for prefix operations.
    public var prefix: Prefix.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Prefix.View = unsafe .init(&self); yield &view }
    }
}
