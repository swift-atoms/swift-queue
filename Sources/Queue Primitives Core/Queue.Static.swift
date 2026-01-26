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

// Note: Queue.Static is unconditionally ~Copyable due to deinit requirement

// MARK: - Properties

extension Queue.Static where Element: ~Copyable {
    /// The current number of elements in the queue.
    @inlinable
    public var count: Int { _count }

    /// Whether the queue is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether the queue is full.
    @inlinable
    public var isFull: Bool { _count == capacity }
}

// MARK: - Core Operations

extension Queue.Static where Element: ~Copyable {
    /// Enqueues an element at the back of the queue.
    ///
    /// - Parameter element: The element to enqueue.
    /// - Throws: ``Queue/Static/Error/overflow`` if the queue is full.
    /// - Complexity: O(1)
    @inlinable
    public mutating func enqueue(_ element: consuming Element) throws(Queue<Element>.Static.Error) {
        guard _count < capacity else {
            throw .overflow
        }
        let ptr = unsafe _pointerToElement(at: _tail)
        unsafe ptr.initialize(to: element)
        _tail = (_tail + 1) % capacity
        _count += 1
    }

    /// Dequeues and returns the front element, or nil if empty.
    ///
    /// - Returns: The front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func dequeue() -> Element? {
        guard _count > 0 else {
            return nil
        }
        let ptr = unsafe _pointerToElement(at: _head)
        let element = unsafe ptr.move()
        _head = (_head + 1) % capacity
        _count -= 1
        return element
    }

    /// Removes all elements from the queue.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        let count = _count
        guard count > 0 else { return }

        let stride = MemoryLayout<Element>.stride
        var index = _head
        unsafe Swift.withUnsafeBytes(of: _storage) { bytes in
            let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
            for _ in 0..<count {
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                unsafe elementPtr.deinitialize(count: 1)
                index = (index + 1) % capacity
            }
        }

        _head = 0
        _tail = 0
        _count = 0
    }
}

// MARK: - Peek

extension Queue.Static where Element: ~Copyable {
    /// Peeks at the front element without removing it.
    ///
    /// Uses a closure to support `~Copyable` elements via borrowing.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the front element.
    /// - Returns: The result of the closure, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek<R>(_ body: (borrowing Element) -> R) -> R? {
        guard _count > 0 else {
            return nil
        }
        let ptr = unsafe _readPointerToElement(at: _head)
        return body(unsafe ptr.pointee)
    }
}

extension Queue.Static where Element: Copyable {
    /// Returns the front element without removing it, or nil if empty.
    ///
    /// This is a convenience method for `Copyable` elements.
    ///
    /// - Returns: A copy of the front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek() -> Element? {
        guard _count > 0 else {
            return nil
        }
        let ptr = unsafe _readPointerToElement(at: _head)
        return unsafe ptr.pointee
    }
}

// MARK: - Iteration (for ~Copyable elements)

extension Queue.Static where Element: ~Copyable {
    /// Calls the given closure for each element in the queue.
    ///
    /// Elements are visited from front (oldest) to back (newest).
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        let count = _count
        guard count > 0 else { return }

        var index = _head
        for _ in 0..<count {
            let ptr = unsafe _readPointerToElement(at: index)
            body(unsafe ptr.pointee)
            index = (index + 1) % capacity
        }
    }
}

// MARK: - Sendable

extension Queue.Static: @unchecked Sendable where Element: Sendable {}
