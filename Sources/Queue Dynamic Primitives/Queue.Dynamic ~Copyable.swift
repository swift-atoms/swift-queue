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
import Index_Primitives

// MARK: - Storage Helper Methods

extension Queue.Storage where Element: ~Copyable {
    /// Deinitializes elements in ring buffer order from head.
    @usableFromInline
    package func _deinitializeAllElements() {
        guard header.count > 0 else { return }
        var index = header.head
        _ = unsafe withUnsafeMutablePointerToElements { ptr in
            for _ in 0..<header.count {
                unsafe (ptr + index.position.rawValue).deinitialize(count: 1)
                index = index.successor(wrapping: capacity)
            }
        }
    }

    /// Moves all elements to new storage, linearizing the ring buffer.
    @usableFromInline
    package func _moveAllElements(to newStorage: Queue<Element>.Storage) {
        guard header.count > 0 else { return }
        var srcIndex = header.head
        var dstIndex: Index<Element> = 0
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                for _ in 0..<header.count {
                    unsafe (dst + dstIndex.position.rawValue).initialize(to: (src + srcIndex.position.rawValue).move())
                    srcIndex = srcIndex.successor(wrapping: capacity)
                    dstIndex = dstIndex.successor()
                }
            }
        }
    }

    /// Initializes element at the given index.
    @usableFromInline
    package func _initializeElement(at index: Int, to element: consuming Element) {
        _ = unsafe withUnsafeMutablePointerToElements { ptr in
            unsafe (ptr + index).initialize(to: element)
        }
    }

    /// Moves element from the given index.
    @usableFromInline
    package func _moveElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { ptr in
            unsafe (ptr + index).move()
        }
    }

    // MARK: - Double-Ended Operations
    //
    // These methods enable Queue.Storage to be used by Queue.DoubleEnded,
    // eliminating the need for a separate storage class.

    /// Converts a logical index (0 = front) to physical ring buffer index.
    @usableFromInline
    package func physicalIndex(_ logicalIndex: Index<Element>) -> Index<Element> {
        header.head.advanced(by: logicalIndex.position).wrapped(capacity: capacity)
    }

    /// Converts a logical index (0 = front) to physical ring buffer index.
    @usableFromInline
    package func physicalIndex(_ logicalIndex: Int) -> Int {
        (header.head.position.rawValue + logicalIndex) % capacity
    }

    /// Appends element at the back (tail position).
    @usableFromInline
    package func append(_ element: consuming Element) {
        _ = unsafe withUnsafeMutablePointerToElements { ptr in
            unsafe (ptr + header.tail.position.rawValue).initialize(to: element)
        }
        header.tail = header.tail.successor(wrapping: capacity)
        header.count += 1
    }

    /// Prepends element at the front (before head).
    @usableFromInline
    package func prepend(_ element: consuming Element) {
        header.head = header.head.predecessor(wrapping: capacity)
        _ = unsafe withUnsafeMutablePointerToElements { ptr in
            unsafe (ptr + header.head.position.rawValue).initialize(to: element)
        }
        header.count += 1
    }

    /// Removes and returns the first element (at head).
    @usableFromInline
    package func removeFirst() -> Element {
        let oldHead = header.head
        header.head = header.head.successor(wrapping: capacity)
        header.count -= 1
        return unsafe withUnsafeMutablePointerToElements { ptr in
            unsafe (ptr + oldHead.position.rawValue).move()
        }
    }

    /// Removes and returns the last element (before tail).
    @usableFromInline
    package func removeLast() -> Element {
        header.count -= 1
        header.tail = header.tail.predecessor(wrapping: capacity)
        return unsafe withUnsafeMutablePointerToElements { ptr in
            unsafe (ptr + header.tail.position.rawValue).move()
        }
    }

    /// Deinitializes all elements and resets head/tail/count.
    @usableFromInline
    package func deinitializeAll() {
        _deinitializeAllElements()
        header = Queue<Element>.Header()
    }
}

// MARK: - Properties

extension Queue where Element: ~Copyable {
    /// The current number of elements in the queue.
    @inlinable
    public var count: Int { _storage.header.count }

    /// Whether the queue is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header.count == 0 }

    /// The current capacity of the queue.
    @inlinable
    public var capacity: Int { _storage.capacity }
}

// MARK: - Capacity Management

extension Queue where Element: ~Copyable {
    /// Ensures the queue has capacity for at least the specified number of elements.
    @usableFromInline
    mutating func ensureCapacity(_ minimumCapacity: Int) {
        guard _storage.capacity < minimumCapacity else { return }

        // Growth factor 2.0, minimum capacity 4
        let newCapacity = Swift.max(minimumCapacity, _storage.capacity * 2, 4)
        let newStorage = Queue<Element>.Storage.create(minimumCapacity: newCapacity)
        let currentCount = _storage.header.count

        _storage._moveAllElements(to: newStorage)
        newStorage.header = (head: 0, tail: currentCount, count: currentCount)
        _storage = newStorage
        unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL: Update cached pointer
    }

    /// Reserves capacity for at least the specified number of elements.
    ///
    /// Use this method to avoid multiple reallocations when adding a known
    /// number of elements.
    ///
    /// - Parameter minimumCapacity: The minimum total capacity to reserve.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        ensureCapacity(minimumCapacity)
    }
}

// MARK: - Core Operations (Base - for ~Copyable elements)

extension Queue where Element: ~Copyable {
    /// Enqueues an element at the back of the queue.
    ///
    /// - Parameter element: The element to enqueue.
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func enqueue(_ element: consuming Element) {
        ensureCapacity(_storage.header.count + 1)
        let tail = _storage.header.tail
        _storage._initializeElement(at: tail, to: element)
        _storage.header.tail = (tail + 1) % _storage.capacity
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
        _storage.header.head = (head + 1) % _storage.capacity
        _storage.header.count -= 1
        return element
    }

    /// Removes all elements from the queue.
    ///
    /// - Parameter keepingCapacity: If `true`, the queue keeps its current capacity.
    ///   If `false`, the storage is released. Default is `true`.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        _storage._deinitializeAllElements()
        _storage.header = (head: 0, tail: 0, count: 0)

        if !keepingCapacity {
            _storage = Storage.create()
            unsafe (_cachedPtr = _storage._elementsPointer)  // Update cached pointer
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
        guard _storage.header.count > 0 else {
            return nil
        }
        let head = _storage.header.head
        return unsafe _storage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + head).pointee)
        }
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
        let count = _storage.header.count
        guard count > 0 else { return }
        let cap = _storage.capacity
        var index = _storage.header.head
        _ = unsafe _storage.withUnsafeMutablePointerToElements { elements in
            for _ in 0..<count {
                body(unsafe (elements + index).pointee)
                index = (index + 1) % cap
            }
        }
    }
}

// MARK: - Capacity Management (Additional)

extension Queue where Element: ~Copyable {
    /// Reduces capacity to match the current count, releasing unused memory.
    ///
    /// After calling this method, `capacity == count`. The ring buffer is
    /// linearized during compaction.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func compact() {
        let currentCount = _storage.header.count
        guard _storage.capacity > currentCount else { return }

        if currentCount == 0 {
            _storage = Storage.create()
            unsafe (_cachedPtr = _storage._elementsPointer)  // Update cached pointer
            return
        }

        let newStorage = Queue<Element>.Storage.create(minimumCapacity: currentCount)
        _storage._moveAllElements(to: newStorage)
        newStorage.header = (head: 0, tail: currentCount, count: currentCount)
        _storage = newStorage
        unsafe (_cachedPtr = _storage._elementsPointer)  // Update cached pointer
    }
}
