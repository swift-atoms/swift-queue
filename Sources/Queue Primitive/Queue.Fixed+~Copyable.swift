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

public import Buffer_Ring_Primitives

// Note: Conditional Copyable conformance and Sequence conformance are in Queue.swift
// (must be same file as declaration due to Swift compiler bug)

// MARK: - Properties

extension Queue.Fixed where Element: ~Copyable {
    /// The current number of elements in the queue.
    @inlinable
    public var count: Index_Primitives.Index<Element>.Count { _buffer.count }

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
        _buffer.push.back(consume element)
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
        return _buffer.pop.front()
    }

    /// Pushes an element to the back of the queue.
    ///
    /// Returns `nil` on success, or the rejected element if the queue is full.
    /// Use this variant when the caller needs the element back on overflow —
    /// essential for `~Copyable` resource types where losing the element is a
    /// correctness bug.
    ///
    /// - Parameter element: The element to push (ownership transferred on success).
    /// - Returns: `nil` if successfully pushed, or the rejected element if full.
    /// - Complexity: O(1)
    @inlinable
    public mutating func push(_ element: consuming Element) -> Element? {
        _buffer.push.back(element)
    }

    /// Removes all elements from the queue.
    ///
    /// The capacity remains unchanged.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        _buffer.remove.all()
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
        _buffer.push.back(element)
    }

    /// Dequeues and returns the front element, or nil if empty (CoW-aware).
    @inlinable
    public mutating func dequeue() -> Element? {
        guard !_buffer.isEmpty else {
            return nil
        }
        return _buffer.pop.front()
    }

    /// Pushes an element to the back of the queue (CoW-aware).
    ///
    /// Returns `nil` on success, or the rejected element if the queue is full.
    ///
    /// - Parameter element: The element to push.
    /// - Returns: `nil` if successfully pushed, or the rejected element if full.
    /// - Complexity: O(1), O(n) if copy triggered
    @inlinable
    public mutating func push(_ element: Element) -> Element? {
        _buffer.push.back(element)
    }

    /// Removes all elements from the queue (CoW-aware).
    @inlinable
    public mutating func clear() {
        _buffer.remove.all()
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
        return _buffer.peek.front
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

// Note: the `Sequence.Drain.Protocol` conformance (cold, brings `Sequence_Primitives`) lives in
// the ops module (Queue.Fixed+Sequence.Drain.swift) per [MOD-004]/[MOD-036].
// Note: Sendable + conditional Copyable conformance declared in Queue.Fixed.swift (the type module).
