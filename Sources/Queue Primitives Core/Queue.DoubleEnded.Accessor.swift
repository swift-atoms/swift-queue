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

public import Property_Primitives

// MARK: - Position Namespaces

extension Queue.DoubleEnded where Element: ~Copyable {
    /// Namespace for front position operations.
    public enum Front {}

    /// Namespace for back position operations.
    public enum Back {}
}

// MARK: - Peek Accessor (Non-Mutating)

extension Queue.DoubleEnded where Element: Copyable {
    /// Accessor for non-mutating peek operations.
    ///
    /// Provides read-only access to front/back elements without requiring
    /// a mutating context.
    public struct PeekAccessor {
        @usableFromInline
        internal let _storage: Queue<Element>.Storage

        @inlinable
        internal init(storage: Queue<Element>.Storage) {
            self._storage = storage
        }

        /// The front element, or `nil` if the deque is empty.
        ///
        /// - Complexity: O(1)
        @inlinable
        public var front: Element? {
            guard _storage.header.count > 0 else { return nil }
            let physicalIndex = _storage.physicalIndex(0)
            return unsafe _storage.withUnsafeMutablePointerToElements { elements in
                unsafe elements[physicalIndex]
            }
        }

        /// The back element, or `nil` if the deque is empty.
        ///
        /// - Complexity: O(1)
        @inlinable
        public var back: Element? {
            let count = _storage.header.count
            guard count > 0 else { return nil }
            let physicalIndex = _storage.physicalIndex(count - 1)
            return unsafe _storage.withUnsafeMutablePointerToElements { elements in
                unsafe elements[physicalIndex]
            }
        }
    }

    /// Non-mutating accessor for peeking at front/back elements.
    ///
    /// Use this for read-only access:
    ///
    /// ```swift
    /// let deque: Deque<Int> = [1, 2, 3]
    ///
    /// let first = deque.peek.front  // 1
    /// let last = deque.peek.back    // 3
    /// ```
    @inlinable
    public var peek: PeekAccessor {
        PeekAccessor(storage: _storage)
    }
}

// MARK: - Front Accessor (Property.View.Typed)

extension Queue.DoubleEnded where Element: Copyable {
    /// Accessor for front position operations.
    ///
    /// Use this to push, pop, or take elements at the front:
    ///
    /// ```swift
    /// var deque: Deque<Int> = [1, 2, 3]
    ///
    /// deque.front.push(0)              // [0, 1, 2, 3]
    /// let removed = try deque.front.pop()  // 0, deque is [1, 2, 3]
    /// let taken = deque.front.take     // 1 or nil
    /// ```
    public var front: Property<Front, Self>.View.Typed<Element> {
        mutating _read {
            yield unsafe Property<Front, Self>.View.Typed(&self)
        }
        mutating _modify {
            var view = unsafe Property<Front, Self>.View.Typed<Element>(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.View.Typed
where Tag == Queue<Element>.DoubleEnded.Front,
      Base == Queue<Element>.DoubleEnded,
      Element: Copyable
{
    /// Returns the front element without removing it.
    ///
    /// - Returns: The front element, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public var peek: Element? {
        guard !(unsafe base.pointee.isEmpty) else { return nil }
        let physicalIndex = unsafe base.pointee._storage.physicalIndex(0)
        return unsafe base.pointee._storage.withUnsafeMutablePointerToElements { elements in
            unsafe elements[physicalIndex]
        }
    }

    /// Pushes an element to the front of the deque.
    ///
    /// - Parameter element: The element to push.
    /// - Complexity: O(1) amortized
    @inlinable
    public func push(_ element: Element) {
        unsafe base.pointee.makeUnique()
        unsafe base.pointee.ensureCapacity(base.pointee.count + 1)
        unsafe base.pointee._storage.prepend(element)
    }

    /// Removes and returns the front element.
    ///
    /// - Returns: The front element.
    /// - Throws: ``Queue/DoubleEnded/Error/empty`` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public func pop() throws(__QueueDoubleEndedError) -> Element {
        unsafe base.pointee.makeUnique()
        guard !(unsafe base.pointee.isEmpty) else {
            throw .invalidCapacity // Using existing error case for empty
        }
        return unsafe base.pointee._storage.removeFirst()
    }

    /// Removes and returns the front element, or nil if empty.
    ///
    /// - Returns: The front element, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public var take: Element? {
        guard !(unsafe base.pointee.isEmpty) else { return nil }
        unsafe base.pointee.makeUnique()
        return unsafe base.pointee._storage.removeFirst()
    }
}

// MARK: - Back Accessor (Property.View.Typed)

extension Queue.DoubleEnded where Element: Copyable {
    /// Accessor for back position operations.
    ///
    /// Use this to push, pop, or take elements at the back:
    ///
    /// ```swift
    /// var deque: Deque<Int> = [1, 2, 3]
    ///
    /// deque.back.push(4)               // [1, 2, 3, 4]
    /// let removed = try deque.back.pop()   // 4, deque is [1, 2, 3]
    /// let taken = deque.back.take      // 3 or nil
    /// ```
    public var back: Property<Back, Self>.View.Typed<Element> {
        mutating _read {
            yield unsafe Property<Back, Self>.View.Typed(&self)
        }
        mutating _modify {
            var view = unsafe Property<Back, Self>.View.Typed<Element>(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.View.Typed
where Tag == Queue<Element>.DoubleEnded.Back,
      Base == Queue<Element>.DoubleEnded,
      Element: Copyable
{
    /// Returns the back element without removing it.
    ///
    /// - Returns: The back element, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public var peek: Element? {
        let count = unsafe base.pointee._storage.header.count
        guard count > 0 else { return nil }
        let physicalIndex = unsafe base.pointee._storage.physicalIndex(count - 1)
        return unsafe base.pointee._storage.withUnsafeMutablePointerToElements { elements in
            unsafe elements[physicalIndex]
        }
    }

    /// Pushes an element to the back of the deque.
    ///
    /// - Parameter element: The element to push.
    /// - Complexity: O(1) amortized
    @inlinable
    public func push(_ element: Element) {
        unsafe base.pointee.makeUnique()
        unsafe base.pointee.ensureCapacity(base.pointee.count + 1)
        unsafe base.pointee._storage.append(element)
    }

    /// Removes and returns the back element.
    ///
    /// - Returns: The back element.
    /// - Throws: ``Queue/DoubleEnded/Error/empty`` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public func pop() throws(__QueueDoubleEndedError) -> Element {
        unsafe base.pointee.makeUnique()
        guard !(unsafe base.pointee.isEmpty) else {
            throw .invalidCapacity // Using existing error case for empty
        }
        return unsafe base.pointee._storage.removeLast()
    }

    /// Removes and returns the back element, or nil if empty.
    ///
    /// - Returns: The back element, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public var take: Element? {
        guard !(unsafe base.pointee.isEmpty) else { return nil }
        unsafe base.pointee.makeUnique()
        return unsafe base.pointee._storage.removeLast()
    }
}
