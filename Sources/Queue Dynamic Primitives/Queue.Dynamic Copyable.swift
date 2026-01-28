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

// MARK: - Typed Subscript (Copyable, with CoW)

extension Queue where Element: Copyable {
    /// Accesses the element at the given typed index with copy-on-write semantics.
    ///
    /// - Parameter index: The typed index of the element to access (0 = front).
    /// - Precondition: `index.position` must be in `0..<count`.
    @inlinable
    public subscript(index: Index) -> Element {
        _read {
            precondition(index.position >= 0 && index.position < _storage.header.count, "Index out of bounds")
            let physicalIndex = (_storage.header.head.position + index.position) % _storage.capacity
            yield unsafe _cachedPtr[physicalIndex]
        }
        _modify {
            makeUnique()
            precondition(index.position >= 0 && index.position < _storage.header.count, "Index out of bounds")
            let physicalIndex = (_storage.header.head.position + index.position) % _storage.capacity
            yield unsafe &_cachedPtr[physicalIndex]
        }
    }
}

// MARK: - Copy-on-Write (Copyable elements only)

extension Queue where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
            unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL: Update cached pointer
        }
    }

    /// Enqueues an element at the back of the queue (CoW-aware).
    ///
    /// - Parameter element: The element to enqueue.
    /// - Complexity: O(1) amortized, O(n) if copy triggered
    @inlinable
    public mutating func enqueue(_ element: Element) {
        makeUnique()
        ensureCapacity(_storage.header.count + 1)
        let tail = _storage.header.tail
        _storage._initializeElement(at: tail, to: element)
        _storage.header.tail = (tail + 1) % _storage.capacity
        _storage.header.count += 1
    }

    /// Dequeues and returns the front element, or nil if empty (CoW-aware).
    ///
    /// - Returns: The front element, or `nil` if the queue is empty.
    /// - Complexity: O(1), O(n) if copy triggered
    @inlinable
    public mutating func dequeue() -> Element? {
        makeUnique()
        guard _storage.header.count > 0 else {
            return nil
        }
        let head = _storage.header.head
        let element = _storage._moveElement(at: head)
        _storage.header.head = (head + 1) % _storage.capacity
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
        makeUnique()
        _storage._deinitializeAllElements()
        _storage.header = (head: 0, tail: 0, count: 0)

        if !keepingCapacity {
            _storage = Storage.create()
            unsafe (_cachedPtr = _storage._elementsPointer)  // Update cached pointer
        }
    }
}

extension Queue {
    /// Returns the front element without removing it, or nil if empty.
    ///
    /// This is a convenience method for `Copyable` elements. For `~Copyable`
    /// elements, use ``peek(_:)`` with a closure.
    ///
    /// - Returns: A copy of the front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek() -> Element? {
        guard _storage.header.count > 0 else {
            return nil
        }
        return _storage._readElement(at: _storage.header.head)
    }
}

// MARK: - Sequence (Copyable elements only)

/// `Queue` conforms to `Sequence` when `Element` is `Copyable`.
///
/// This enables `for-in` loops, `map`, `filter`, and other sequence operations.
/// For `~Copyable` elements, use ``forEach(_:)`` instead.
extension Queue: Swift.Sequence where Element: Copyable {

    /// An iterator over the elements of a queue.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _storage: Queue<Element>.Storage

        @usableFromInline
        var _current: Int

        @usableFromInline
        var _remaining: Int

        @usableFromInline
        init(storage: Queue<Element>.Storage) {
            self._storage = storage
            self._current = storage.header.head
            self._remaining = storage.header.count
        }

        /// Advances to the next element and returns it, or nil if no next element exists.
        @inlinable
        public mutating func next() -> Element? {
            guard _remaining > 0 else { return nil }
            let element = _storage._readElement(at: _current)
            _current = (_current + 1) % _storage.capacity
            _remaining -= 1
            return element
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

// MARK: - CoW-aware Capacity Management (Copyable elements)

extension Queue where Element: Copyable {
    /// Reduces capacity to match the current count, releasing unused memory (CoW-aware).
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func compact() {
        makeUnique()
        let currentCount = _storage.header.count
        guard _storage.capacity > currentCount else { return }

        if currentCount == 0 {
            _storage = Storage.create()
            unsafe (_cachedPtr = _storage._elementsPointer)  // Update cached pointer
            return
        }

        let newStorage = Queue<Element>.Storage.create(minimumCapacity: currentCount)
        _storage._copyAllElements(to: newStorage)
        newStorage.header = (head: 0, tail: currentCount, count: currentCount)
        _storage = newStorage
        unsafe (_cachedPtr = _storage._elementsPointer)  // Update cached pointer
    }
}

// MARK: - Storage Copyable Helpers

extension Queue.Storage where Element: Copyable {

    /// Creates a copy of this storage with all elements duplicated and linearized.
    @usableFromInline
    func copy() -> Queue.Storage {
        let count = header.count
        guard count > 0 else {
            return Queue.Storage.create()
        }

        let new = Queue.Storage.create(minimumCapacity: capacity)
        new.header = (head: 0, tail: count, count: count)

        // Copy elements in ring buffer order, linearizing
        let cap = capacity
        var srcIndex = header.head
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe new.withUnsafeMutablePointerToElements { dst in
                for dstIndex in 0..<count {
                    unsafe (dst + dstIndex).initialize(to: src[srcIndex])
                    srcIndex = (srcIndex + 1) % cap
                }
            }
        }

        return new
    }

    /// Reads element at the given index.
    @usableFromInline
    package func _readElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe elements[index]
        }
    }

    /// Copies all elements to new storage (linearized).
    @usableFromInline
    func _copyAllElements(to newStorage: Queue.Storage) {
        let count = header.count
        guard count > 0 else { return }
        let cap = capacity
        var srcIndex = header.head
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                for dstIndex in 0..<count {
                    unsafe (dst + dstIndex).initialize(to: src[srcIndex])
                    srcIndex = (srcIndex + 1) % cap
                }
            }
        }
    }
}
