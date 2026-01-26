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
// MARK: - Queue.Linked.Storage Helper Methods
// ============================================================================

extension Queue.Linked.Storage where Element: ~Copyable {
    @usableFromInline
    package var _nodesPointer: UnsafeMutablePointer<Queue<Element>.Linked.Node> {
        unsafe withUnsafeMutablePointerToElements { unsafe $0 }
    }

    @usableFromInline
    package func _initializeNode(at index: Int, element: consuming Element, nextIndex: Int) {
        let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
        unsafe ptr.initialize(to: Queue<Element>.Linked.Node(element: element, nextIndex: nextIndex))
    }

    @usableFromInline
    package func _loadFreeNext(at index: Int) -> Int {
        unsafe withUnsafeMutablePointerToElements { ptr in
            unsafe UnsafeRawPointer(ptr.advanced(by: index)).load(as: Int.self)
        }
    }

    @usableFromInline
    package func _storeFreeNext(at index: Int, next: Int) {
        unsafe withUnsafeMutablePointerToElements { ptr in
            unsafe UnsafeMutableRawPointer(ptr.advanced(by: index)).storeBytes(of: next, as: Int.self)
        }
    }

    @usableFromInline
    package func _moveAllElements(to newStorage: Queue<Element>.Linked.Storage) {
        let count = header.count
        guard count > 0 else { return }

        var srcIndex = header.head
        var dstIndex = 0
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                while srcIndex >= 0 {
                    let nextSrcIndex = unsafe src[srcIndex].nextIndex
                    let newNextIndex = dstIndex + 1 < count ? dstIndex + 1 : -1

                    unsafe (dst + dstIndex).initialize(
                        to: Queue<Element>.Linked.Node(element: (src + srcIndex).move().element, nextIndex: newNextIndex)
                    )

                    srcIndex = nextSrcIndex
                    dstIndex += 1
                }
            }
        }

        header.head = -1
        header.tail = -1
        header.freeHead = -1
        header.count = 0
    }
}

// ============================================================================
// MARK: - Queue.Linked Extensions
// ============================================================================
// NOTE: All Queue.Linked extensions MUST be in the same module due to
// Swift compiler bug [MEM-COPY-006] Category 3: Protocol conformances
// and extensions for nested types break ~Copyable propagation when split.

// MARK: - Queue.Linked Properties

extension Queue.Linked where Element: ~Copyable {
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

// MARK: - Queue.Linked Capacity Management

extension Queue.Linked where Element: ~Copyable {
    /// Ensures the queue has capacity for at least the specified number of elements.
    @usableFromInline
    mutating func _ensureCapacity(_ minimumCapacity: Int) {
        guard _storage.capacity < minimumCapacity else { return }

        let newCapacity = Swift.max(minimumCapacity, _storage.capacity * 2, 4)
        let newStorage = Queue<Element>.Linked.Storage.create(minimumCapacity: newCapacity)
        let currentCount = _storage.header.count

        _storage._moveAllElements(to: newStorage)
        newStorage.header.head = currentCount > 0 ? 0 : -1
        newStorage.header.tail = currentCount > 0 ? currentCount - 1 : -1
        newStorage.header.count = currentCount
        newStorage.header.capacity = newCapacity
        _storage = newStorage
    }

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

    /// Reserves capacity for at least the specified number of elements.
    ///
    /// Use this method to avoid multiple reallocations when adding a known
    /// number of elements.
    ///
    /// - Parameter minimumCapacity: The minimum total capacity to reserve.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        _ensureCapacity(minimumCapacity)
    }
}

// MARK: - Queue.Linked Core Operations (~Copyable)

extension Queue.Linked where Element: ~Copyable {
    /// Enqueues an element at the back of the queue.
    ///
    /// - Parameter element: The element to enqueue.
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func enqueue(_ element: consuming Element) {
        _ensureCapacity(_storage.header.count + 1)
        let newIndex = _allocateSlot()

        // Initialize node with next = -1 (new tail)
        _storage._initializeNode(at: newIndex, element: element, nextIndex: -1)

        // Update old tail's next link
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

        // Capture next index BEFORE move
        let nextIndex: Int = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe nodes[headIndex].nextIndex
        }

        // Update header
        _storage.header.head = nextIndex
        if nextIndex < 0 {
            _storage.header.tail = -1
        }

        // Move element out (deinitializes node)
        let element: Element = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + headIndex).move().element
        }

        // Add to free list
        _storage._storeFreeNext(at: headIndex, next: _storage.header.freeHead)
        _storage.header.freeHead = headIndex

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
        guard _storage.header.count > 0 else { return }

        // Deinitialize all nodes
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

// MARK: - Queue.Linked Peek

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
        guard _storage.header.count > 0 else { return nil }
        let headIndex = _storage.header.head
        return unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            body(unsafe nodes[headIndex].element)
        }
    }
}

// MARK: - Queue.Linked ForEach

extension Queue.Linked where Element: ~Copyable {
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
