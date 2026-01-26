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

// ============================================================================
// MARK: - Queue.Linked.Bounded Extensions
// ============================================================================

// MARK: - Queue.Linked.Bounded Properties

extension Queue.Linked.Bounded where Element: ~Copyable {
    /// The current number of elements in the queue.
    @inlinable
    public var count: Int { _storage.header.count }

    /// Whether the queue is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header.count == 0 }

    /// Whether the queue is at capacity.
    @inlinable
    public var isFull: Bool { _storage.header.count >= capacity }
}

// MARK: - Queue.Linked.Bounded Core Operations (~Copyable)

extension Queue.Linked.Bounded where Element: ~Copyable {
    /// Allocates a node slot, returning its index.
    @usableFromInline
    mutating func _allocateSlot() -> Int {
        if _storage.header.freeHead >= 0 {
            let index = _storage.header.freeHead
            _storage.header.freeHead = _storage._loadFreeNext(at: index)
            return index
        }
        return _storage.header.count
    }

    /// Enqueues an element at the back of the queue.
    ///
    /// - Parameter element: The element to enqueue.
    /// - Throws: ``Bounded/Error/overflow`` if the queue is at capacity.
    /// - Complexity: O(1)
    @inlinable
    public mutating func enqueue(_ element: consuming Element) throws(__QueueLinkedBoundedError) {
        guard _storage.header.count < capacity else {
            throw .overflow
        }

        let newIndex = _allocateSlot()

        _storage._initializeNode(at: newIndex, element: element, nextIndex: -1)

        if _storage.header.tail >= 0 {
            let nodes = unsafe _storage._nodesPointer
            unsafe (nodes[_storage.header.tail].nextIndex = newIndex)
        }

        if _storage.header.head < 0 {
            _storage.header.head = newIndex
        }

        _storage.header.tail = newIndex
        _storage.header.count += 1
    }

    /// Dequeues and returns the front element, or nil if empty.
    ///
    /// - Returns: The front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func dequeue() -> Element? {
        guard _storage.header.count > 0 else { return nil }

        let headIndex = _storage.header.head

        let nextIndex: Int = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe nodes[headIndex].nextIndex
        }

        _storage.header.head = nextIndex
        if nextIndex < 0 {
            _storage.header.tail = -1
        }

        let element: Element = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + headIndex).move().element
        }

        _storage._storeFreeNext(at: headIndex, next: _storage.header.freeHead)
        _storage.header.freeHead = headIndex

        _storage.header.count -= 1
        return element
    }

    /// Removes all elements from the queue.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        guard _storage.header.count > 0 else { return }

        var index = _storage.header.head
        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            while index >= 0 {
                let nextIndex = unsafe nodes[index].nextIndex
                unsafe (nodes + index).deinitialize(count: 1)
                index = nextIndex
            }
        }

        _storage.header.head = -1
        _storage.header.tail = -1
        _storage.header.freeHead = -1
        _storage.header.count = 0
    }
}

// MARK: - Queue.Linked.Bounded Copy-on-Write (Copyable elements only)

extension Queue.Linked.Bounded where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func _makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
        }
    }

    /// Enqueues an element at the back of the queue (CoW-aware).
    ///
    /// - Parameter element: The element to enqueue.
    /// - Throws: ``Bounded/Error/overflow`` if the queue is at capacity.
    /// - Complexity: O(1), O(n) if copy triggered
    @inlinable
    public mutating func enqueue(_ element: Element) throws(__QueueLinkedBoundedError) {
        _makeUnique()
        guard _storage.header.count < capacity else {
            throw .overflow
        }

        let newIndex = _allocateSlot()

        _storage._initializeNode(at: newIndex, element: element, nextIndex: -1)

        if _storage.header.tail >= 0 {
            let nodes = unsafe _storage._nodesPointer
            unsafe (nodes[_storage.header.tail].nextIndex = newIndex)
        }

        if _storage.header.head < 0 {
            _storage.header.head = newIndex
        }

        _storage.header.tail = newIndex
        _storage.header.count += 1
    }

    /// Dequeues and returns the front element, or nil if empty (CoW-aware).
    ///
    /// - Returns: The front element, or `nil` if the queue is empty.
    /// - Complexity: O(1), O(n) if copy triggered
    @inlinable
    public mutating func dequeue() -> Element? {
        _makeUnique()
        guard _storage.header.count > 0 else { return nil }

        let headIndex = _storage.header.head

        var element: Element?
        var nextIndex: Int = -1
        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            element = unsafe nodes[headIndex].element
            nextIndex = unsafe nodes[headIndex].nextIndex
        }

        _storage.header.head = nextIndex
        if nextIndex < 0 {
            _storage.header.tail = -1
        }

        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + headIndex).deinitialize(count: 1)
        }

        _storage._storeFreeNext(at: headIndex, next: _storage.header.freeHead)
        _storage.header.freeHead = headIndex

        _storage.header.count -= 1
        return element
    }

    /// Removes all elements from the queue (CoW-aware).
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        _makeUnique()
        guard _storage.header.count > 0 else { return }

        var index = _storage.header.head
        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            while index >= 0 {
                let nextIndex = unsafe nodes[index].nextIndex
                unsafe (nodes + index).deinitialize(count: 1)
                index = nextIndex
            }
        }

        _storage.header.head = -1
        _storage.header.tail = -1
        _storage.header.freeHead = -1
        _storage.header.count = 0
    }
}

// MARK: - Queue.Linked.Bounded Peek

extension Queue.Linked.Bounded where Element: ~Copyable {
    /// Peeks at the front element without removing it.
    ///
    /// Uses a closure to support `~Copyable` elements via borrowing.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the front element.
    /// - Returns: The result of the closure, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek<R>(_ body: (borrowing Element) -> R) -> R? {
        guard _storage.header.count > 0 else { return nil }
        let headIndex = _storage.header.head
        return unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            body(unsafe nodes[headIndex].element)
        }
    }
}

extension Queue.Linked.Bounded {
    /// Returns the front element without removing it, or nil if empty.
    ///
    /// This is a convenience method for `Copyable` elements. For `~Copyable`
    /// elements, use ``peek(_:)`` with a closure.
    ///
    /// - Returns: A copy of the front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek() -> Element? {
        guard _storage.header.count > 0 else { return nil }
        let headIndex = _storage.header.head
        return unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe nodes[headIndex].element
        }
    }
}

// MARK: - Queue.Linked.Bounded ForEach

extension Queue.Linked.Bounded where Element: ~Copyable {
    /// Calls the given closure for each element in the queue.
    ///
    /// Elements are visited from front (oldest) to back (newest).
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        var index = _storage.header.head
        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            while index >= 0 {
                body(unsafe nodes[index].element)
                index = unsafe nodes[index].nextIndex
            }
        }
    }
}

// MARK: - Queue.Linked.Bounded Sequence (Copyable elements only)

/// `Queue.Linked.Bounded` conforms to `Sequence` when `Element` is `Copyable`.
///
/// This enables `for-in` loops, `map`, `filter`, and other sequence operations.
/// For `~Copyable` elements, use ``forEach(_:)`` instead.
extension Queue.Linked.Bounded: Swift.Sequence where Element: Copyable {

    /// An iterator over the elements of a bounded linked queue.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _storage: Queue<Element>.Linked.Storage

        @usableFromInline
        var _current: Int

        @usableFromInline
        init(storage: Queue<Element>.Linked.Storage) {
            self._storage = storage
            self._current = storage.header.head
        }

        /// Advances to the next element and returns it, or nil if no next element exists.
        @inlinable
        public mutating func next() -> Element? {
            guard _current >= 0 else { return nil }
            return unsafe _storage.withUnsafeMutablePointerToElements { nodes in
                let element = unsafe nodes[_current].element
                _current = unsafe nodes[_current].nextIndex
                return element
            }
        }
    }

    /// Returns an iterator over the elements of the queue.
    ///
    /// Elements are yielded from front (oldest) to back (newest).
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(storage: _storage)
    }
}

// MARK: - Queue.Linked.Bounded Equatable

extension Queue.Linked.Bounded: Equatable where Element: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }

        var lhsIndex = lhs._storage.header.head
        var rhsIndex = rhs._storage.header.head

        while lhsIndex >= 0 && rhsIndex >= 0 {
            let lhsElement = unsafe lhs._storage.withUnsafeMutablePointerToElements { nodes in
                unsafe nodes[lhsIndex].element
            }
            let rhsElement = unsafe rhs._storage.withUnsafeMutablePointerToElements { nodes in
                unsafe nodes[rhsIndex].element
            }

            if lhsElement != rhsElement { return false }

            lhsIndex = unsafe lhs._storage.withUnsafeMutablePointerToElements { nodes in
                unsafe nodes[lhsIndex].nextIndex
            }
            rhsIndex = unsafe rhs._storage.withUnsafeMutablePointerToElements { nodes in
                unsafe nodes[rhsIndex].nextIndex
            }
        }

        return true
    }
}

// MARK: - Queue.Linked.Bounded Hashable

extension Queue.Linked.Bounded: Hashable where Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_storage.header.count)
        forEach { hasher.combine($0) }
    }
}

// MARK: - Queue.Linked.Bounded Sendable

extension Queue.Linked.Bounded: @unchecked Sendable where Element: Sendable {}

// MARK: - Queue.Linked Error Types

extension Queue.Linked where Element: ~Copyable {
    /// Errors that can occur during linked queue operations.
    ///
    /// ## Cases
    ///
    /// - ``Queue/Linked/Error/empty``: The queue is empty and the operation requires elements.
    /// - ``Queue/Linked/Error/invalidCapacity``: The requested capacity is invalid (negative).
    public typealias Error = __QueueLinkedError
}

extension Queue.Linked.Bounded where Element: ~Copyable {
    /// Errors that can occur during bounded linked queue operations.
    ///
    /// ## Cases
    ///
    /// - ``Queue/Linked/Bounded/Error/empty``: The queue is empty and the operation requires elements.
    /// - ``Queue/Linked/Bounded/Error/invalidCapacity``: The requested capacity is invalid (negative).
    /// - ``Queue/Linked/Bounded/Error/overflow``: The queue is full and cannot accept more elements.
    public typealias Error = __QueueLinkedBoundedError
}
