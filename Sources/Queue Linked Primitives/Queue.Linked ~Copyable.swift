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
public import Buffer_Linked_Primitives

// MARK: - Properties

extension Queue.Linked where Element: ~Copyable {
    /// The current number of elements in the queue.
    @inlinable
    public var count: Index<Element>.Count { _buffer.count }

    /// Whether the queue is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// The current capacity of the queue.
    @inlinable
    public var capacity: Index<Element>.Count { _buffer.capacity.retag(Element.self) }
}

// MARK: - Capacity Management

extension Queue.Linked where Element: ~Copyable {
    /// Ensures the queue has capacity for one additional element.
    @usableFromInline
    mutating func _ensureCapacityForOneMore() {
        try! _buffer.ensureCapacity(Int(bitPattern: _buffer.count) + 1)
    }

    /// Reserves capacity for at least the specified number of elements.
    ///
    /// Use this method to avoid multiple reallocations when adding a known
    /// number of elements.
    ///
    /// - Parameter minimumCapacity: The minimum total capacity to reserve.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        try! _buffer.ensureCapacity(minimumCapacity)
    }
}

// MARK: - Core Operations (~Copyable)

extension Queue.Linked where Element: ~Copyable {
    /// Enqueues an element at the back of the queue.
    ///
    /// - Parameter element: The element to enqueue.
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func enqueue(_ element: consuming Element) {
        _ensureCapacityForOneMore()
        try! _buffer.insert.back(element)
    }

    /// Dequeues and returns the front element, or nil if empty.
    ///
    /// - Returns: The front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func dequeue() -> Element? {
        _buffer.remove.front()
    }

    /// Removes all elements from the queue.
    ///
    /// - Parameter keepingCapacity: If `true`, the queue keeps its current capacity.
    ///   If `false`, the storage is released. Default is `true`.
    /// - Complexity: O(n) where n is the number of elements.
    // WORKAROUND: @_optimize(none) suppresses CopyPropagation false positive
    // on removeAll() + conditional buffer reassignment in deep @inlinable chain.
    // WHEN TO REMOVE: When swiftlang/swift fixes SIL ownership verification in CopyPropagation.
    // TRACKING: swift-buffer-primitives/Research/rawlayout-release-crash-investigation.md (Bug 2)
    @_optimize(none)
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        _buffer.removeAll()
        if !keepingCapacity {
            self._buffer = try! .create(capacity: 4)
        }
    }
}

// MARK: - Peek

extension Queue.Linked where Element: ~Copyable {
    /// Peeks at the front element without removing it.
    ///
    /// Uses a closure to support `~Copyable` elements via borrowing.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the front element.
    /// - Returns: The result of the closure, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek<R>(_ body: (borrowing Element) -> R) -> R? {
        _buffer.peekFront(body)
    }
}

// MARK: - ForEach

extension Queue.Linked where Element: ~Copyable {
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
