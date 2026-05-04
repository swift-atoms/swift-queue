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

public import List_Linked_Primitives
public import Queue_Primitives_Core

// ============================================================================
// MARK: - Queue.Linked.Inline Extensions
// ============================================================================

// MARK: - Queue.Linked.Inline Properties

extension Queue.Linked.Inline where Element: Copyable {
    /// The current number of elements in the queue.
    public var count: Index<Element>.Count { _storage.count }

    /// Whether the queue is empty.
    public var isEmpty: Bool { _storage.isEmpty }

    /// Whether the queue is at capacity.
    public var isFull: Bool { _storage.isFull }
}

// MARK: - Queue.Linked.Inline Core Operations

extension Queue.Linked.Inline where Element: Copyable {
    /// Enqueues an element at the back of the queue.
    ///
    /// - Parameter element: The element to enqueue.
    /// - Throws: ``Inline/Error/overflow`` if the queue is at capacity.
    /// - Complexity: O(1)
    public mutating func enqueue(_ element: Element) throws(Queue<Element>.Linked.Inline<capacity>.Error) {
        do throws(__ListLinkedInlineError) {
            try _storage.append(element)
        } catch {
            switch error {
            case .overflow: throw .overflow
            case .empty: fatalError("Unexpected error: empty")
            }
        }
    }

    /// Dequeues and returns the front element, or nil if empty.
    ///
    /// - Returns: The front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    public mutating func dequeue() -> Element? {
        _storage.popFirst()
    }

    /// Removes all elements from the queue.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    public mutating func clear() {
        _storage.clear()
    }
}

// MARK: - Queue.Linked.Inline Peek

extension Queue.Linked.Inline where Element: Copyable {
    /// Returns the front element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    public func peek() -> Element? {
        _storage.first
    }
}

// MARK: - Queue.Linked.Inline Conditional Drain

extension Queue.Linked.Inline where Element: Copyable {
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

// MARK: - Queue.Linked.Inline ForEach

extension Queue.Linked.Inline where Element: Copyable {
    /// Calls the given closure for each element in the queue.
    ///
    /// Elements are visited from front (oldest) to back (newest).
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    public func forEach(_ body: (Element) -> Void) {
        _storage.forEach(body)
    }
}

// MARK: - Queue.Linked.Inline Sendable

extension Queue.Linked.Inline: @unchecked Sendable where Element: Sendable {}

// ============================================================================
// MARK: - Queue.Linked.Small Extensions
// ============================================================================

// MARK: - Queue.Linked.Small Properties

extension Queue.Linked.Small where Element: Copyable {
    /// The current number of elements in the queue.
    public var count: Index<Element>.Count { _storage.count }

    /// Whether the queue is empty.
    public var isEmpty: Bool { _storage.isEmpty }

    /// The current capacity of the queue.
    public var capacity: Index<Element>.Count { _storage.capacity }
}

// MARK: - Queue.Linked.Small Core Operations

extension Queue.Linked.Small where Element: Copyable {
    /// Enqueues an element at the back of the queue.
    ///
    /// - Parameter element: The element to enqueue.
    /// - Complexity: O(1) amortized
    public mutating func enqueue(_ element: Element) {
        _storage.append(element)
    }

    /// Dequeues and returns the front element, or nil if empty.
    ///
    /// - Returns: The front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    public mutating func dequeue() -> Element? {
        _storage.popFirst()
    }

    /// Removes all elements from the queue.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    public mutating func clear() {
        _storage.clear()
    }
}

// MARK: - Queue.Linked.Small Peek

extension Queue.Linked.Small where Element: Copyable {
    /// Returns the front element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    public func peek() -> Element? {
        _storage.first
    }
}

// MARK: - Queue.Linked.Small Conditional Drain

extension Queue.Linked.Small where Element: Copyable {
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

// MARK: - Queue.Linked.Small ForEach

extension Queue.Linked.Small where Element: Copyable {
    /// Calls the given closure for each element in the queue.
    ///
    /// Elements are visited from front (oldest) to back (newest).
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    public func forEach(_ body: (Element) -> Void) {
        _storage.forEach(body)
    }
}

// MARK: - Queue.Linked.Small Sendable

extension Queue.Linked.Small: @unchecked Sendable where Element: Sendable {}
