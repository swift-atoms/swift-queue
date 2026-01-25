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

// Note: Queue.DoubleEnded struct declaration is in Queue.swift
// (must be same file due to Swift compiler bug [MEM-COPY-006])
// This file contains extensions with operations and conformances.

// MARK: - Error Typealiases

extension Queue.DoubleEnded where Element: ~Copyable {
    /// Errors that can occur during double-ended queue operations.
    public typealias Error = __QueueDoubleEndedError
}

extension Queue.DoubleEndedFixed where Element: ~Copyable {
    /// Errors that can occur during fixed-capacity double-ended queue operations.
    public typealias Error = __QueueDoubleEndedFixedError
}

extension Queue.DoubleEndedStatic {
    /// Errors that can occur during static double-ended queue operations.
    public typealias Error = __QueueDoubleEndedStaticError
}

extension Queue.DoubleEndedSmall {
    /// Errors that can occur during small double-ended queue operations.
    public typealias Error = __QueueDoubleEndedSmallError
}

// MARK: - Deque Typealias

/// A double-ended queue (deque) with O(1) amortized operations at both ends.
///
/// `Deque` is a typealias for ``Queue/DoubleEnded``. It provides a familiar
/// name for users coming from other languages or libraries.
///
/// - SeeAlso: ``Queue/DoubleEnded``
public typealias Deque<Element: ~Copyable> = Queue<Element>.DoubleEnded

// MARK: - DoubleEnded Properties (~Copyable)

extension Queue.DoubleEnded where Element: ~Copyable {
    /// The current number of elements in the deque.
    @inlinable
    public var count: Int { _storage.header.count }

    /// Whether the deque is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header.count == 0 }

    /// The current capacity of the deque.
    @inlinable
    public var capacity: Int { _storage.header.bufferCapacity }
}

// MARK: - DoubleEnded Capacity Management (~Copyable)

extension Queue.DoubleEnded where Element: ~Copyable {
    /// Ensures the storage has capacity for at least the specified number of elements.
    @usableFromInline
    mutating func ensureCapacity(_ minimumCapacity: Int) {
        let currentCapacity = _storage.header.bufferCapacity
        guard currentCapacity < minimumCapacity else { return }

        let newCapacity = Swift.max(minimumCapacity, currentCapacity * 2, 4)
        let newStorage = Storage.create(minimumCapacity: newCapacity)

        let count = _storage.header.count
        let head = _storage.header.head
        let oldCapacity = currentCapacity

        if count > 0 {
            unsafe _storage.withUnsafeMutablePointerToElements { src in
                unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                    for i in 0..<count {
                        let srcIndex = (head + i) % oldCapacity
                        unsafe (dst + i).initialize(to: (src + srcIndex).move())
                    }
                }
            }
        }

        newStorage.header.count = count
        newStorage.header.head = 0
        _storage.header.count = 0

        _storage = newStorage
    }

    /// Reserves enough space to store the specified number of elements.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        ensureCapacity(minimumCapacity)
    }
}

// MARK: - DoubleEnded Core Operations (~Copyable)

extension Queue.DoubleEnded where Element: ~Copyable {
    /// Pushes an element to the specified end of the deque.
    ///
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func push(_ element: consuming Element, to position: Position) {
        ensureCapacity(count + 1)
        switch position {
        case .front:
            _storage.prepend(element)
        case .back:
            _storage.append(element)
        }
    }

    /// Pops and returns an element from the specified end, or nil if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func pop(from position: Position) -> Element? {
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _storage.removeFirst()
        case .back:
            return _storage.removeLast()
        }
    }

    /// Takes and returns an element from the specified end, or nil if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func take(from position: Position) -> Element? {
        pop(from: position)
    }

    /// Removes all elements from the deque.
    ///
    /// - Complexity: O(n)
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        if !keepingCapacity {
            _storage = Storage.create()
        } else {
            _storage.deinitializeAll()
        }
    }
}

// MARK: - DoubleEnded Peek (~Copyable)

extension Queue.DoubleEnded where Element: ~Copyable {
    /// Peeks at the element at the specified end without removing it.
    ///
    /// - Complexity: O(1)
    @inlinable
    public func peek<R>(at position: Position, _ body: (borrowing Element) -> R) -> R? {
        guard !isEmpty else { return nil }
        let logicalIndex = position == .front ? 0 : count - 1
        let physicalIndex = _storage.physicalIndex(logicalIndex)
        return unsafe _storage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + physicalIndex).pointee)
        }
    }
}

// MARK: - DoubleEnded forEach (~Copyable)

extension Queue.DoubleEnded where Element: ~Copyable {
    /// Calls the given closure for each element in the deque.
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        let count = self.count
        guard count > 0 else { return }
        let cap = _storage.header.bufferCapacity
        let head = _storage.header.head

        _ = unsafe _storage.withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                let physicalIndex = (head + i) % cap
                body(unsafe (elements + physicalIndex).pointee)
            }
        }
    }
}

// MARK: - DoubleEnded Copy-on-Write (Copyable)

extension Queue.DoubleEnded where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
        }
    }

    /// Pushes an element (CoW-aware).
    @inlinable
    public mutating func push(_ element: Element, to position: Position) {
        makeUnique()
        ensureCapacity(count + 1)
        switch position {
        case .front:
            _storage.prepend(element)
        case .back:
            _storage.append(element)
        }
    }

    /// Pops an element (CoW-aware).
    @inlinable
    public mutating func pop(from position: Position) -> Element? {
        makeUnique()
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _storage.removeFirst()
        case .back:
            return _storage.removeLast()
        }
    }

    /// Takes an element (CoW-aware).
    @inlinable
    public mutating func take(from position: Position) -> Element? {
        pop(from: position)
    }

    /// Removes all elements (CoW-aware).
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        makeUnique()
        if !keepingCapacity {
            _storage = Storage.create()
        } else {
            _storage.deinitializeAll()
        }
    }

    /// Returns the element at the specified end without removing it.
    @inlinable
    public func peek(at position: Position) -> Element? {
        guard !isEmpty else { return nil }
        let logicalIndex = position == .front ? 0 : count - 1
        return _readElement(at: logicalIndex)
    }

    /// Reads the element at the given logical index.
    @usableFromInline
    package func _readElement(at logicalIndex: Int) -> Element {
        let physicalIndex = _storage.physicalIndex(logicalIndex)
        return unsafe _storage.withUnsafeMutablePointerToElements { elements in
            unsafe elements[physicalIndex]
        }
    }
}

// MARK: - Storage Copy (Copyable)

extension Queue._DoubleEndedStorage where Element: Copyable {
    /// Creates a copy of this storage with all elements duplicated.
    @usableFromInline
    func copy() -> Queue._DoubleEndedStorage {
        let count = header.count
        guard count > 0 else {
            return Queue._DoubleEndedStorage.create()
        }

        let new = Queue._DoubleEndedStorage.create(minimumCapacity: header.bufferCapacity)
        (new.header.count = count)
        (new.header.head = 0)

        let cap = header.bufferCapacity
        let head = header.head

        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe new.withUnsafeMutablePointerToElements { dst in
                for i in 0..<count {
                    let srcIndex = (head + i) % cap
                    unsafe (dst + i).initialize(to: src[srcIndex])
                }
            }
        }

        return new
    }
}

// MARK: - Fixed Properties (~Copyable)

extension Queue.DoubleEndedFixed where Element: ~Copyable {
    /// The current number of elements in the deque.
    @inlinable
    public var count: Int { _storage.header.count }

    /// Whether the deque is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header.count == 0 }

    /// Whether the deque is full.
    @inlinable
    public var isFull: Bool { _storage.header.count == capacity }
}

// MARK: - Fixed Core Operations (~Copyable)

extension Queue.DoubleEndedFixed where Element: ~Copyable {
    /// Pushes an element to the specified end.
    ///
    /// - Throws: ``Queue/DoubleEnded/Fixed/Error/overflow`` if the deque is full.
    @inlinable
    public mutating func push(
        _ element: consuming Element,
        to position: Queue<Element>.DoubleEnded.Position
    ) throws(Queue<Element>.DoubleEndedFixed.Error) {
        guard !isFull else { throw .overflow }
        switch position {
        case .front:
            _storage.prepend(element)
        case .back:
            _storage.append(element)
        }
    }

    /// Pops an element from the specified end, or nil if empty.
    @inlinable
    public mutating func pop(from position: Queue<Element>.DoubleEnded.Position) -> Element? {
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _storage.removeFirst()
        case .back:
            return _storage.removeLast()
        }
    }

    /// Takes an element from the specified end, or nil if empty.
    @inlinable
    public mutating func take(from position: Queue<Element>.DoubleEnded.Position) -> Element? {
        pop(from: position)
    }

    /// Peeks at the element at the specified end.
    @inlinable
    public func peek<R>(
        at position: Queue<Element>.DoubleEnded.Position,
        _ body: (borrowing Element) -> R
    ) -> R? {
        guard !isEmpty else { return nil }
        let logicalIndex = position == .front ? 0 : count - 1
        let physicalIndex = _storage.physicalIndex(logicalIndex)
        return unsafe _storage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + physicalIndex).pointee)
        }
    }

    /// Removes all elements from the deque.
    @inlinable
    public mutating func clear() {
        _storage.deinitializeAll()
    }

    /// Calls the given closure for each element.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        let count = self.count
        guard count > 0 else { return }
        let cap = _storage.header.bufferCapacity
        let head = _storage.header.head

        _ = unsafe _storage.withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                let physicalIndex = (head + i) % cap
                body(unsafe (elements + physicalIndex).pointee)
            }
        }
    }
}

// MARK: - Fixed Copy-on-Write (Copyable)

extension Queue.DoubleEndedFixed where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
        }
    }

    /// Pushes an element (CoW-aware).
    @inlinable
    public mutating func push(
        _ element: Element,
        to position: Queue<Element>.DoubleEnded.Position
    ) throws(Queue<Element>.DoubleEndedFixed.Error) {
        makeUnique()
        guard !isFull else { throw .overflow }
        switch position {
        case .front:
            _storage.prepend(element)
        case .back:
            _storage.append(element)
        }
    }

    /// Pops an element (CoW-aware).
    @inlinable
    public mutating func pop(from position: Queue<Element>.DoubleEnded.Position) -> Element? {
        makeUnique()
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _storage.removeFirst()
        case .back:
            return _storage.removeLast()
        }
    }

    /// Takes an element (CoW-aware).
    @inlinable
    public mutating func take(from position: Queue<Element>.DoubleEnded.Position) -> Element? {
        pop(from: position)
    }

    /// Clears all elements (CoW-aware).
    @inlinable
    public mutating func clear() {
        makeUnique()
        _storage.deinitializeAll()
    }

    /// Returns the element at the specified end without removing it.
    @inlinable
    public func peek(at position: Queue<Element>.DoubleEnded.Position) -> Element? {
        guard !isEmpty else { return nil }
        let logicalIndex = position == .front ? 0 : count - 1
        let physicalIndex = _storage.physicalIndex(logicalIndex)
        return unsafe _storage.withUnsafeMutablePointerToElements { elements in
            unsafe elements[physicalIndex]
        }
    }
}

// MARK: - Static Properties and Operations

extension Queue.DoubleEndedStatic {
    /// The current number of elements.
    @inlinable
    public var count: Int { _count }

    /// Whether the deque is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether the deque is full.
    @inlinable
    public var isFull: Bool { _count == Self.capacity }

    @usableFromInline
    @unsafe
    package mutating func _pointerToElement(at physicalIndex: Int) -> UnsafeMutablePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe Swift.withUnsafeMutablePointer(to: &_storage) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe (basePtr + physicalIndex * stride).assumingMemoryBound(to: Element.self)
            return unsafe elementPtr
        }
    }

    @usableFromInline
    @unsafe
    package func _readPointerToElement(at physicalIndex: Int) -> UnsafePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe Swift.withUnsafePointer(to: _storage) { storagePtr in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe (basePtr + physicalIndex * stride).assumingMemoryBound(to: Element.self)
            return unsafe elementPtr
        }
    }

    @usableFromInline
    package func _physicalIndex(_ logicalIndex: Int) -> Int {
        (_head + logicalIndex) % Self.capacity
    }

    /// Pushes an element to the specified end.
    @inlinable
    public mutating func push(
        _ element: consuming Element,
        to position: Queue<Element>.DoubleEnded.Position
    ) throws(Queue<Element>.DoubleEndedStatic<capacity>.Error) {
        guard !isFull else { throw .overflow }
        switch position {
        case .back:
            let tail = _physicalIndex(_count)
            unsafe _pointerToElement(at: tail).initialize(to: element)
            _count += 1
        case .front:
            let newHead = (_head - 1 + Self.capacity) % Self.capacity
            unsafe _pointerToElement(at: newHead).initialize(to: element)
            _head = newHead
            _count += 1
        }
    }

    /// Pops an element from the specified end, or nil if empty.
    @inlinable
    public mutating func pop(from position: Queue<Element>.DoubleEnded.Position) -> Element? {
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            let elementPtr = unsafe _pointerToElement(at: _head)
            _head = (_head + 1) % Self.capacity
            _count -= 1
            return unsafe elementPtr.move()
        case .back:
            _count -= 1
            let tail = _physicalIndex(_count)
            return unsafe _pointerToElement(at: tail).move()
        }
    }

    /// Takes an element from the specified end, or nil if empty.
    @inlinable
    public mutating func take(from position: Queue<Element>.DoubleEnded.Position) -> Element? {
        pop(from: position)
    }

    /// Peeks at the element at the specified end.
    @inlinable
    public func peek<R>(
        at position: Queue<Element>.DoubleEnded.Position,
        _ body: (borrowing Element) -> R
    ) -> R? {
        guard !isEmpty else { return nil }
        let logicalIndex = position == .front ? 0 : _count - 1
        let physicalIndex = _physicalIndex(logicalIndex)
        return unsafe body(_readPointerToElement(at: physicalIndex).pointee)
    }

    /// Removes all elements.
    @inlinable
    public mutating func clear() {
        let count = _count
        let head = _head
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafeMutablePointer(to: &_storage) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            for i in 0..<count {
                let physicalIndex = (head + i) % capacity
                let elementPtr = unsafe (basePtr + physicalIndex * stride).assumingMemoryBound(to: Element.self)
                unsafe elementPtr.deinitialize(count: 1)
            }
        }
        _count = 0
        _head = 0
    }

    /// Calls the given closure for each element.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        guard _count > 0 else { return }
        for i in 0..<_count {
            let physicalIndex = _physicalIndex(i)
            body(unsafe _readPointerToElement(at: physicalIndex).pointee)
        }
    }
}

// MARK: - Small Properties and Operations

extension Queue.DoubleEndedSmall {
    /// Whether the deque is currently using heap storage.
    @inlinable
    public var isSpilled: Bool { _heap != nil }

    /// The current number of elements.
    @inlinable
    public var count: Int { _count }

    /// Whether the deque is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    @usableFromInline
    @unsafe
    package mutating func _inlinePointerToElement(at physicalIndex: Int) -> UnsafeMutablePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe Swift.withUnsafeMutablePointer(to: &_inline) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe (basePtr + physicalIndex * stride).assumingMemoryBound(to: Element.self)
            return unsafe elementPtr
        }
    }

    @usableFromInline
    @unsafe
    package func _inlineReadPointerToElement(at physicalIndex: Int) -> UnsafePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe Swift.withUnsafePointer(to: _inline) { storagePtr in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe (basePtr + physicalIndex * stride).assumingMemoryBound(to: Element.self)
            return unsafe elementPtr
        }
    }

    @usableFromInline
    package func _inlinePhysicalIndex(_ logicalIndex: Int) -> Int {
        (_head + logicalIndex) % inlineCapacity
    }

    @usableFromInline
    package mutating func _spillToHeap(minimumCapacity: Int) {
        precondition(_heap == nil, "Already spilled")
        let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
        let newStorage = Queue._DoubleEndedStorage.create(minimumCapacity: newCapacity)
        newStorage.header.count = _count
        newStorage.header.head = 0

        let stride = MemoryLayout<Element>.stride
        _ = unsafe Swift.withUnsafeBytes(of: _inline) { bytes in
            unsafe newStorage.withUnsafeMutablePointerToElements { heapPtr in
                let inlineBase = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                for i in 0..<_count {
                    let physicalIndex = (_head + i) % inlineCapacity
                    let inlineElement = unsafe (inlineBase + physicalIndex * stride).assumingMemoryBound(to: Element.self)
                    unsafe (heapPtr + i).initialize(to: inlineElement.move())
                }
            }
        }

        _head = 0
        _heap = newStorage
    }

    /// Pushes an element to the specified end.
    @inlinable
    public mutating func push(
        _ element: consuming Element,
        to position: Queue<Element>.DoubleEnded.Position
    ) {
        if let heap = _heap {
            if heap.header.count >= heap.header.bufferCapacity {
                let newCapacity = heap.header.bufferCapacity * 2
                let newStorage = Queue._DoubleEndedStorage.create(minimumCapacity: newCapacity)
                let count = _count

                _ = unsafe heap.withUnsafeMutablePointerToElements { src in
                    unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                        let head = heap.header.head
                        let cap = heap.header.bufferCapacity
                        for i in 0..<count {
                            let srcIndex = (head + i) % cap
                            unsafe (dst + i).initialize(to: (src + srcIndex).move())
                        }
                    }
                }

                newStorage.header.count = count
                newStorage.header.head = 0
                heap.header.count = 0
                _heap = newStorage
            }

            switch position {
            case .back:
                _heap!.append(element)
            case .front:
                _heap!.prepend(element)
            }
            _count += 1
        } else if _count < inlineCapacity {
            switch position {
            case .back:
                let tail = _inlinePhysicalIndex(_count)
                unsafe _inlinePointerToElement(at: tail).initialize(to: element)
                _count += 1
            case .front:
                let newHead = (_head - 1 + inlineCapacity) % inlineCapacity
                unsafe _inlinePointerToElement(at: newHead).initialize(to: element)
                _head = newHead
                _count += 1
            }
        } else {
            _spillToHeap(minimumCapacity: inlineCapacity + 1)
            switch position {
            case .back:
                _heap!.append(element)
            case .front:
                _heap!.prepend(element)
            }
            _count += 1
        }
    }

    /// Pops an element from the specified end, or nil if empty.
    @inlinable
    public mutating func pop(from position: Queue<Element>.DoubleEnded.Position) -> Element? {
        guard !isEmpty else { return nil }

        if let heap = _heap {
            _count -= 1
            switch position {
            case .front:
                return heap.removeFirst()
            case .back:
                return heap.removeLast()
            }
        } else {
            switch position {
            case .front:
                let elementPtr = unsafe _inlinePointerToElement(at: _head)
                _head = (_head + 1) % inlineCapacity
                _count -= 1
                return unsafe elementPtr.move()
            case .back:
                _count -= 1
                let tail = _inlinePhysicalIndex(_count)
                return unsafe _inlinePointerToElement(at: tail).move()
            }
        }
    }

    /// Takes an element from the specified end, or nil if empty.
    @inlinable
    public mutating func take(from position: Queue<Element>.DoubleEnded.Position) -> Element? {
        pop(from: position)
    }

    /// Peeks at the element at the specified end.
    @inlinable
    public func peek<R>(
        at position: Queue<Element>.DoubleEnded.Position,
        _ body: (borrowing Element) -> R
    ) -> R? {
        guard !isEmpty else { return nil }

        if let heap = _heap {
            let logicalIndex = position == .front ? 0 : _count - 1
            let physicalIndex = heap.physicalIndex(logicalIndex)
            return unsafe heap.withUnsafeMutablePointerToElements { heapPtr in
                body(unsafe (heapPtr + physicalIndex).pointee)
            }
        } else {
            let logicalIndex = position == .front ? 0 : _count - 1
            let physicalIndex = _inlinePhysicalIndex(logicalIndex)
            return unsafe body(_inlineReadPointerToElement(at: physicalIndex).pointee)
        }
    }

    /// Removes all elements.
    @inlinable
    public mutating func clear() {
        let count = _count
        if let heap = _heap {
            heap.deinitializeAll()
            _count = 0
        } else {
            let head = _head
            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafeMutablePointer(to: &_inline) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                for i in 0..<count {
                    let physicalIndex = (head + i) % inlineCapacity
                    let elementPtr = unsafe (basePtr + physicalIndex * stride).assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
            _count = 0
            _head = 0
        }
    }

    /// Calls the given closure for each element.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        guard _count > 0 else { return }

        if let heap = _heap {
            let head = heap.header.head
            let cap = heap.header.bufferCapacity
            _ = unsafe heap.withUnsafeMutablePointerToElements { heapPtr in
                for i in 0..<_count {
                    let physicalIndex = (head + i) % cap
                    body(unsafe (heapPtr + physicalIndex).pointee)
                }
            }
        } else {
            for i in 0..<_count {
                let physicalIndex = _inlinePhysicalIndex(i)
                body(unsafe _inlineReadPointerToElement(at: physicalIndex).pointee)
            }
        }
    }
}

// MARK: - Sequence (Copyable)

extension Queue.DoubleEnded: Swift.Sequence where Element: Copyable {
    /// An iterator over the elements of a double-ended queue.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _storage: Queue._DoubleEndedStorage

        @usableFromInline
        var _index: Int = 0

        @usableFromInline
        let _count: Int

        @usableFromInline
        init(storage: Queue._DoubleEndedStorage) {
            self._storage = storage
            self._count = storage.header.count
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _index < _count else { return nil }
            defer { _index += 1 }
            let physicalIndex = _storage.physicalIndex(_index)
            return unsafe _storage.withUnsafeMutablePointerToElements { elements in
                unsafe elements[physicalIndex]
            }
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(storage: _storage)
    }
}

extension Queue.DoubleEnded.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: - Equatable (Copyable)

extension Queue.DoubleEnded: Equatable where Element: Equatable & Copyable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for i in 0..<lhs.count {
            if lhs._readElement(at: i) != rhs._readElement(at: i) {
                return false
            }
        }
        return true
    }
}

// MARK: - Hashable (Copyable)

extension Queue.DoubleEnded: Hashable where Element: Hashable & Copyable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for i in 0..<count {
            hasher.combine(_readElement(at: i))
        }
    }
}

// MARK: - ExpressibleByArrayLiteral (Copyable)

extension Queue.DoubleEnded: ExpressibleByArrayLiteral where Element: Copyable {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init()
        for element in elements {
            push(element, to: .back)
        }
    }
}

// MARK: - Sequence Initializer (Copyable)

extension Queue.DoubleEnded where Element: Copyable {
    /// Creates a deque containing the elements of a sequence.
    @inlinable
    public init<S: Swift.Sequence>(_ elements: S) where S.Element == Element {
        self.init()
        for element in elements {
            push(element, to: .back)
        }
    }
}

// MARK: - CustomStringConvertible

#if !hasFeature(Embedded)
extension Queue.DoubleEnded: CustomStringConvertible where Element: Copyable {
    public var description: String {
        var result = "Queue.DoubleEnded(["
        var first = true
        for i in 0..<count {
            if !first { result += ", " }
            result += String(describing: _readElement(at: i))
            first = false
        }
        result += "])"
        return result
    }
}
#endif

// MARK: - Internal CoW Identity (for testing)

extension Queue.DoubleEnded where Element: Copyable {
    /// Buffer identity for CoW testing.
    @usableFromInline
    internal var _identity: ObjectIdentifier {
        ObjectIdentifier(_storage)
    }
}
