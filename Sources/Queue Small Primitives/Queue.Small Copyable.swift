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

// Note: Queue.Small is unconditionally ~Copyable (inline storage requires deinit),
// so it cannot conform to Swift.Sequence which requires Copyable.
// It conforms to Sequence.Protocol which supports ~Copyable containers.

// ============================================================================
// MARK: - Iterator
// ============================================================================

extension Queue.Small where Element: Copyable {
    /// Iterator for Queue.Small elements.
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
        return Iterator(_buffer: snapshot)
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

// ============================================================================
// MARK: - Sequence Tag Enums
// ============================================================================

extension Queue.Small where Element: Copyable {
    public enum Drain {
        public typealias View = Property<Sequence.Drain, Queue<Element>.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
    public enum ForEach {
        public typealias View = Property<Sequence.ForEach, Queue<Element>.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
    public enum Satisfies {
        public typealias View = Property<Sequence.Satisfies, Queue<Element>.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }

    public enum Reduce {
        public typealias View = Property<Sequence.Reduce, Queue<Element>.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
    public enum Contains {
        public typealias View = Property<Sequence.Contains, Queue<Element>.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
    public enum Drop {
        public typealias View = Property<Sequence.Drop, Queue<Element>.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
    public enum Prefix {
        public typealias View = Property<Sequence.Prefix, Queue<Element>.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
}

// ============================================================================
// MARK: - Property Accessors
// ============================================================================

extension Queue.Small where Element: Copyable {
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
