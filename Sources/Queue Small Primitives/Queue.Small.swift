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
import Queue_Dynamic_Primitives

// Note: Queue.Small is unconditionally ~Copyable due to deinit requirement

// MARK: - Internal Helpers

extension Queue.Small where Element: ~Copyable {
    /// Returns a mutable pointer to the inline element at the given index.
    @usableFromInline
    @unsafe
    package mutating func _inlinePointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe Swift.withUnsafeMutablePointer(to: &_inline) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe (basePtr + index * stride)
                .assumingMemoryBound(to: Element.self)
            return unsafe elementPtr
        }
    }

    /// Returns a read-only pointer to the inline element at the given index.
    @usableFromInline
    @unsafe
    package func _inlineReadPointerToElement(at index: Int) -> UnsafePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe Swift.withUnsafePointer(to: _inline) { storagePtr in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe (basePtr + index * stride)
                .assumingMemoryBound(to: Element.self)
            return unsafe elementPtr
        }
    }

    /// Spills inline storage to heap, linearizing the ring buffer.
    @usableFromInline
    package mutating func _spillToHeap(minimumCapacity: Int) {
        precondition(_heap == nil, "Already spilled")

        // Create heap storage with growth factor
        let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
        let newStorage = Queue<Element>.Storage.create(minimumCapacity: newCapacity)
        newStorage.header = (head: Index(position: 0), tail: Index(position: _count), count: Index<Element>.Count(__unchecked: _count))

        // Move elements from inline (ring buffer) to heap (linear)
        let stride = MemoryLayout<Element>.stride
        var srcIndex = _head
        _ = unsafe Swift.withUnsafeBytes(of: _inline) { bytes in
            unsafe newStorage.withUnsafeMutablePointerToElements { heapPtr in
                let inlineBase = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                for dstIndex in 0..<_count {
                    let inlineElement = unsafe (inlineBase + srcIndex * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe (heapPtr + dstIndex).initialize(to: inlineElement.move())
                    srcIndex = (srcIndex + 1) % inlineCapacity
                }
            }
        }

        _heap = newStorage
        unsafe (_heapPtr = newStorage._elementsPointer)
    }
}

// MARK: - Properties

extension Queue.Small where Element: ~Copyable {
    /// The current number of elements in the queue.
    @inlinable
    public var count: Int { _count }

    /// Whether the queue is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// The current capacity of the queue.
    @inlinable
    public var capacity: Int {
        if let heap = _heap {
            return heap.capacity
        }
        return inlineCapacity
    }
}

// MARK: - Core Operations

extension Queue.Small where Element: ~Copyable {
    /// Enqueues an element at the back of the queue.
    ///
    /// - Parameter element: The element to enqueue.
    /// - Complexity: O(1) amortized. O(n) when spilling from inline to heap.
    @inlinable
    public mutating func enqueue(_ element: consuming Element) {
        if _heap != nil {
            // Already on heap - check capacity and grow if needed
            _enqueueToHeap(element)
        } else {
            // Using inline storage
            if _count >= inlineCapacity {
                // Spill to heap then enqueue
                _spillToHeap(minimumCapacity: inlineCapacity + 1)
                _enqueueToHeap(element)
            } else {
                // Enqueue inline
                _enqueueInline(element)
            }
        }
    }

    /// Internal: enqueue to heap storage.
    @usableFromInline
    mutating func _enqueueToHeap(_ element: consuming Element) {
        guard let heap = _heap else {
            preconditionFailure("_enqueueToHeap called without heap storage")
        }
        if _count >= heap.capacity {
            _growHeapStorage()
        }
        let updatedHeap = _heap!
        let tail = updatedHeap.header.tail
        updatedHeap._initializeElement(at: tail, to: element)
        updatedHeap.header.tail = (tail + 1) % updatedHeap.capacity
        updatedHeap.header.count += 1
        _count += 1
    }

    /// Internal: enqueue to inline storage.
    @usableFromInline
    mutating func _enqueueInline(_ element: consuming Element) {
        let ptr = unsafe _inlinePointerToElement(at: _tail)
        unsafe ptr.initialize(to: element)
        _tail = (_tail + 1) % inlineCapacity
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

        if let heap = _heap {
            // Dequeue from heap
            let head = heap.header.head
            let element = heap._moveElement(at: head)
            heap.header.head = (head + 1) % heap.capacity
            heap.header.count -= 1
            _count -= 1
            return element
        } else {
            // Dequeue from inline
            let ptr = unsafe _inlinePointerToElement(at: _head)
            let element = unsafe ptr.move()
            _head = (_head + 1) % inlineCapacity
            _count -= 1
            return element
        }
    }

    /// Removes all elements from the queue.
    ///
    /// - Parameter keepingCapacity: If `true` and spilled to heap, keeps heap capacity.
    ///   If `false`, reverts to inline storage. Default is `true`.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        guard _count > 0 else {
            if !keepingCapacity && _heap != nil {
                _heap = nil
                unsafe (_heapPtr = nil)
            }
            return
        }

        if let heap = _heap {
            // Clear heap storage
            heap._deinitializeAllElements()
            heap.header = (head: 0, tail: 0, count: 0)
            if !keepingCapacity {
                _heap = nil
                unsafe (_heapPtr = nil)
            }
        } else {
            // Clear inline storage
            let stride = MemoryLayout<Element>.stride
            var index = _head
            unsafe Swift.withUnsafeBytes(of: _inline) { bytes in
                let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                for _ in 0..<_count {
                    let elementPtr = unsafe (basePtr + index * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                    index = (index + 1) % inlineCapacity
                }
            }
        }

        _head = 0
        _tail = 0
        _count = 0
    }

    /// Grows heap storage when capacity is exceeded.
    @usableFromInline
    mutating func _growHeapStorage() {
        guard let heap = _heap else {
            preconditionFailure("_growHeapStorage called without heap storage")
        }

        let newCapacity = Swift.max(heap.capacity * 2, 8)
        let newStorage = Queue<Element>.Storage.create(minimumCapacity: newCapacity)
        heap._moveAllElements(to: newStorage)
        newStorage.header = (head: 0, tail: _count, count: _count)

        _heap = newStorage
        unsafe (_heapPtr = newStorage._elementsPointer)
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
        guard _count > 0 else {
            return nil
        }

        if let heap = _heap {
            let head = heap.header.head
            return unsafe heap.withUnsafeMutablePointerToElements { elements in
                body(unsafe (elements + head).pointee)
            }
        } else {
            let ptr = unsafe _inlineReadPointerToElement(at: _head)
            return body(unsafe ptr.pointee)
        }
    }
}

extension Queue.Small where Element: Copyable {
    /// Returns the front element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek() -> Element? {
        guard _count > 0 else {
            return nil
        }

        if let heap = _heap {
            return heap._readElement(at: heap.header.head)
        } else {
            let ptr = unsafe _inlineReadPointerToElement(at: _head)
            return unsafe ptr.pointee
        }
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
        let count = _count
        guard count > 0 else { return }

        if let heap = _heap {
            let cap = heap.capacity
            var index = heap.header.head
            _ = unsafe heap.withUnsafeMutablePointerToElements { elements in
                for _ in 0..<count {
                    body(unsafe (elements + index).pointee)
                    index = (index + 1) % cap
                }
            }
        } else {
            var index = _head
            for _ in 0..<count {
                let ptr = unsafe _inlineReadPointerToElement(at: index)
                body(unsafe ptr.pointee)
                index = (index + 1) % inlineCapacity
            }
        }
    }
}

// MARK: - Sendable

extension Queue.Small: @unchecked Sendable where Element: Sendable {}
