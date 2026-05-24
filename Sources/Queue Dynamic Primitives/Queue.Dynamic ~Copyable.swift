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

public import Buffer_Ring_Primitive
public import Buffer_Ring_Primitives
public import Queue_Primitives_Core

// MARK: - Properties

extension Queue where Element: ~Copyable {
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

// MARK: - Core Operations (Base - for ~Copyable elements)

extension Queue where Element: ~Copyable {
    /// Enqueues an element at the back of the queue.
    ///
    /// - Parameter element: The element to enqueue.
    /// - Complexity: O(1) amortized
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
    /// - Parameter keepingCapacity: If `true`, the queue keeps its current capacity.
    ///   If `false`, the storage is released. Default is `true`.
    /// - Complexity: O(n) where n is the number of elements.
    // on remove.all() + conditional buffer reassignment in deep @inlinable chain.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        _buffer.remove.all()

        if !keepingCapacity {
            _buffer = Buffer<Element>.Ring(minimumCapacity: .zero)
        }
    }
}

// MARK: - Peek

extension Queue where Element: ~Copyable {
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

// MARK: - Span Access
//
// Note: Ring buffer queues may have non-contiguous storage (wrapping).
// Full Span access requires linearizing, which we avoid for efficiency.
// Instead, provide forEach-based iteration for ~Copyable elements.

extension Queue where Element: ~Copyable {
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

// MARK: - Capacity Management (Additional)

extension Queue where Element: ~Copyable {
    /// Reserves capacity for at least the specified number of elements.
    ///
    /// Use this method to avoid multiple reallocations when adding a known
    /// number of elements.
    ///
    /// - Parameter minimumCapacity: The minimum total capacity to reserve.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Index_Primitives.Index<Element>.Count) {
        _buffer.reserveCapacity(minimumCapacity)
    }

    /// Reduces capacity to match the current count, releasing unused memory.
    ///
    /// After calling this method, `capacity == count`. The ring buffer is
    /// linearized during compaction.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func compact() {
        _buffer.compact()
    }
}

// MARK: - Sequence.Drain.Protocol (~Copyable)

extension Queue: Sequence.Drain.`Protocol` where Element: ~Copyable {
    /// Drains all elements in FIFO order, passing each to the closure with ownership.
    ///
    /// After this method returns, the queue is empty but still usable.
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
