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

// MARK: - Queue.Linked Copy-on-Write (Copyable elements only)

extension Queue.Linked where Element: Copyable {
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
    /// - Complexity: O(1) amortized, O(n) if copy triggered
    @inlinable
    public mutating func enqueue(_ element: Element) {
        _makeUnique()
        _ensureCapacity(_storage.header.count + 1)
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

        // Capture element and next BEFORE deinitialize
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

        // Deinitialize the node
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
    /// - Parameter keepingCapacity: If `true`, the queue keeps its current capacity.
    ///   If `false`, the storage is released. Default is `true`.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
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

        if keepingCapacity {
            _storage.header.head = -1
            _storage.header.tail = -1
            _storage.header.freeHead = -1
            _storage.header.count = 0
        } else {
            _storage = Queue<Element>.Linked.Storage.create()
        }
    }
}

extension Queue.Linked {
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

// MARK: - Queue.Linked Sequence (Copyable elements only)

/// `Queue.Linked` conforms to `Sequence` when `Element` is `Copyable`.
///
/// This enables `for-in` loops, `map`, `filter`, and other sequence operations.
/// For `~Copyable` elements, use ``forEach(_:)`` instead.
extension Queue.Linked: Swift.Sequence where Element: Copyable {

    /// An iterator over the elements of a linked queue.
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

// MARK: - Queue.Linked Equatable

extension Queue.Linked: Equatable where Element: Equatable {
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

// MARK: - Queue.Linked Hashable

extension Queue.Linked: Hashable where Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_storage.header.count)
        forEach { hasher.combine($0) }
    }
}

// MARK: - Queue.Linked Sendable

extension Queue.Linked: @unchecked Sendable where Element: Sendable {}

// MARK: - Queue.Linked.Storage Copyable Helpers

extension Queue.Linked.Storage where Element: Copyable {
    @usableFromInline
    func copy() -> Queue<Element>.Linked.Storage {
        let count = header.count
        guard count > 0 else {
            return Queue<Element>.Linked.Storage.create()
        }

        let new = Queue<Element>.Linked.Storage.create(minimumCapacity: capacity)
        new.header = Queue<Element>.Linked.Header()
        new.header.head = 0
        new.header.tail = count - 1
        new.header.freeHead = -1
        new.header.count = count
        new.header.capacity = capacity

        var srcIndex = header.head
        var dstIndex = 0
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe new.withUnsafeMutablePointerToElements { dst in
                while srcIndex >= 0 {
                    let newNextIndex = dstIndex + 1 < count ? dstIndex + 1 : -1
                    unsafe (dst + dstIndex).initialize(
                        to: Queue<Element>.Linked.Node(
                            element: src[srcIndex].element,
                            nextIndex: newNextIndex
                        )
                    )
                    srcIndex = unsafe src[srcIndex].nextIndex
                    dstIndex += 1
                }
            }
        }

        return new
    }
}
