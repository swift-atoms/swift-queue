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
import Buffer_Primitives

// Note: Conditional Copyable conformance and Sequence conformance are in Queue.swift
// (must be same file as declaration due to Swift compiler bug)

// MARK: - Properties

extension Queue.Fixed where Element: ~Copyable {
    /// The current number of elements in the queue.
    @inlinable
    public var count: Int { Int(_buffer.count.rawValue.rawValue) }

    /// Whether the queue is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// Whether the queue is full.
    @inlinable
    public var isFull: Bool { count >= capacity }
}

// MARK: - Core Operations (Base - for ~Copyable elements)

extension Queue.Fixed where Element: ~Copyable {
    /// Enqueues an element at the back of the queue.
    ///
    /// - Parameter element: The element to enqueue.
    /// - Throws: ``Queue/Bounded/Error/overflow`` if the queue is full.
    /// - Complexity: O(1)
    @inlinable
    public mutating func enqueue(_ element: consuming Element) throws(Queue<Element>.Fixed.Error) {
        guard count < capacity else {
            throw .overflow
        }
        _ = _buffer.pushBack(consume element)
    }

    /// Dequeues and returns the front element, or nil if empty.
    ///
    /// - Returns: The front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func dequeue() -> Element? {
        guard !_buffer.isEmpty else {
            return nil
        }
        return _buffer.popFront()
    }

    /// Removes all elements from the queue.
    ///
    /// The capacity remains unchanged.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        _buffer.removeAll()
    }
}

// MARK: - Copy-on-Write (Copyable elements only)

extension Queue.Fixed where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        _buffer.ensureUnique()
    }

    /// Enqueues an element at the back of the queue (CoW-aware).
    @inlinable
    public mutating func enqueue(_ element: Element) throws(Queue<Element>.Fixed.Error) {
        guard count < capacity else {
            throw .overflow
        }
        _ = _buffer.pushBack(element)
    }

    /// Dequeues and returns the front element, or nil if empty (CoW-aware).
    @inlinable
    public mutating func dequeue() -> Element? {
        guard !_buffer.isEmpty else {
            return nil
        }
        return _buffer.popFront()
    }

    /// Removes all elements from the queue (CoW-aware).
    @inlinable
    public mutating func clear() {
        _buffer.removeAll()
    }
}

// MARK: - Peek

extension Queue.Fixed where Element: ~Copyable {
    /// Peeks at the front element without removing it.
    @inlinable
    public func peek<R>(_ body: (borrowing Element) -> R) -> R? {
        guard !_buffer.isEmpty else {
            return nil
        }
        return _buffer.withFront(body)
    }
}

extension Queue.Fixed where Element: Copyable {
    /// Returns the front element without removing it, or nil if empty.
    @inlinable
    public func peek() -> Element? {
        guard !_buffer.isEmpty else {
            return nil
        }
        return _buffer.peekFront
    }
}

// MARK: - Iteration (for ~Copyable elements)

extension Queue.Fixed where Element: ~Copyable {
    /// Calls the given closure for each element in the queue.
    ///
    /// Elements are visited from front (oldest) to back (newest).
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        _buffer.forEach(body)
    }
}

// MARK: - Sendable

extension Queue.Fixed: @unchecked Sendable where Element: Sendable {}

// Note: Swift.Sequence conformance for Queue.Fixed is in Queue.swift
// (must be in same file as declaration due to Swift compiler bug with ~Copyable)
