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
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
public import Buffer_Ring_Inline_Primitives
public import Buffer_Ring_Small_Primitive

// Note: Queue.Small is unconditionally ~Copyable due to deinit requirement

// MARK: - Properties

extension Queue.Small where Element: ~Copyable {
    /// The current number of elements in the queue.
    @inlinable
    public var count: Index_Primitives.Index<Element>.Count { _buffer.count }

    /// Whether the queue is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// The current capacity of the queue.
    @inlinable
    public var capacity: Index_Primitives.Index<Element>.Count { _buffer.capacity }
}

// MARK: - Core Operations

extension Queue.Small where Element: ~Copyable {
    /// Enqueues an element at the back of the queue.
    ///
    /// - Parameter element: The element to enqueue.
    /// - Complexity: O(1) amortized. O(n) when spilling from inline to heap.
    @inlinable
    public mutating func enqueue(_ element: consuming Element) {
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

    /// Removes all elements from the queue.
    ///
    /// - Parameter keepingCapacity: If `true` and spilled to heap, keeps heap capacity.
    ///   If `false`, reverts to inline storage. Default is `true`.
    /// - Complexity: O(n) where n is the number of elements.
    // on remove.all() + conditional buffer reassignment in deep @inlinable chain.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        _buffer.remove.all()
        if !keepingCapacity {
            _buffer = Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Ring.Small<inlineCapacity>()
        }
    }
}

// MARK: - Peek

extension Queue.Small where Element: ~Copyable {
    /// Peeks at the front element without removing it.
    ///
    /// Uses a closure to support `~Copyable` elements via borrowing.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the front element.
    /// - Returns: The result of the closure, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek<R>(_ body: (borrowing Element) -> R) -> R? {
        guard !_buffer.isEmpty else {
            return nil
        }
        return _buffer.withFront(body)
    }
}

extension Queue.Small where Element: Copyable {
    /// Returns the front element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek() -> Element? {
        guard !_buffer.isEmpty else {
            return nil
        }
        return _buffer.peek.front
    }
}

// MARK: - Iteration (for ~Copyable elements)

extension Queue.Small where Element: ~Copyable {
    /// Calls the given closure for each element in the queue.
    ///
    /// Elements are visited from front (oldest) to back (newest).
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        _buffer.forEach(body)
    }
}

// Note: Sendable conformance declared in Queue.swift (Queue_Primitives_Core)
