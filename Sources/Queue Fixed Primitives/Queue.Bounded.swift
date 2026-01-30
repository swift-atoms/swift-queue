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

// Note: Conditional Copyable conformance and Sequence conformance are in Queue.swift
// (must be same file as declaration due to Swift compiler bug)

// MARK: - Properties

extension Queue.Fixed where Element: ~Copyable {
    /// The current number of elements in the queue.
    @inlinable
    public var count: Int { _storage.header.count }

    /// Whether the queue is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header.count == 0 }

    /// Whether the queue is full.
    @inlinable
    public var isFull: Bool { _storage.header.count == capacity }
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
        guard _storage.header.count < capacity else {
            throw .overflow
        }
        let tail = _storage.header.tail
        _storage._initializeElement(at: tail, to: element)
        _storage.header.tail = (tail + 1) % capacity
        _storage.header.count += 1
    }

    /// Dequeues and returns the front element, or nil if empty.
    ///
    /// - Returns: The front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func dequeue() -> Element? {
        guard _storage.header.count > 0 else {
            return nil
        }
        let head = _storage.header.head
        let element = _storage._moveElement(at: head)
        _storage.header.head = (head + 1) % capacity
        _storage.header.count -= 1
        return element
    }

    /// Removes all elements from the queue.
    ///
    /// The capacity remains unchanged.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        _storage._deinitializeAllElements()
        _storage.header = (head: 0, tail: 0, count: 0)
    }
}

// MARK: - Copy-on-Write (Copyable elements only)

extension Queue.Fixed where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
            unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL: Update cached pointer
        }
    }

    /// Enqueues an element at the back of the queue (CoW-aware).
    @inlinable
    public mutating func enqueue(_ element: Element) throws(Queue<Element>.Fixed.Error) {
        makeUnique()
        guard _storage.header.count < capacity else {
            throw .overflow
        }
        let tail = _storage.header.tail
        _storage._initializeElement(at: tail, to: element)
        _storage.header.tail = (tail + 1) % capacity
        _storage.header.count += 1
    }

    /// Dequeues and returns the front element, or nil if empty (CoW-aware).
    @inlinable
    public mutating func dequeue() -> Element? {
        makeUnique()
        guard _storage.header.count > 0 else {
            return nil
        }
        let head = _storage.header.head
        let element = _storage._moveElement(at: head)
        _storage.header.head = (head + 1) % capacity
        _storage.header.count -= 1
        return element
    }

    /// Removes all elements from the queue (CoW-aware).
    @inlinable
    public mutating func clear() {
        makeUnique()
        _storage._deinitializeAllElements()
        _storage.header = (head: 0, tail: 0, count: 0)
    }
}

// MARK: - Peek

extension Queue.Fixed where Element: ~Copyable {
    /// Peeks at the front element without removing it.
    @inlinable
    public func peek<R>(_ body: (borrowing Element) -> R) -> R? {
        guard _storage.header.count > 0 else {
            return nil
        }
        let head = _storage.header.head
        return unsafe body((_cachedPtr + head).pointee)
    }
}

extension Queue.Fixed where Element: Copyable {
    /// Returns the front element without removing it, or nil if empty.
    @inlinable
    public func peek() -> Element? {
        guard _storage.header.count > 0 else {
            return nil
        }
        return _storage._readElement(at: _storage.header.head)
    }
}

// MARK: - Iteration (for ~Copyable elements)

extension Queue.Fixed where Element: ~Copyable {
    /// Calls the given closure for each element in the queue.
    ///
    /// Elements are visited from front (oldest) to back (newest).
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        let count = _storage.header.count
        guard count > 0 else { return }
        var index = _storage.header.head
        for _ in 0..<count {
            body(unsafe (_cachedPtr + index).pointee)
            index = (index + 1) % capacity
        }
    }
}

// MARK: - Sendable

extension Queue.Fixed: @unchecked Sendable where Element: Sendable {}

// Note: Swift.Sequence conformance for Queue.Fixed is in Queue.swift
// (must be in same file as declaration due to Swift compiler bug with ~Copyable)
