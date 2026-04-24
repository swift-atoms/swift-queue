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
public import Property_Primitives
public import Buffer_Ring_Primitives

// MARK: - Position Namespaces

extension Queue.DoubleEnded where Element: ~Copyable {
    /// Namespace for front position operations.
    public enum Front {
        public typealias View = Property<Queue<Element>.DoubleEnded.Front, Queue<Element>.DoubleEnded>.View.Typed<Element>
    }

    /// Namespace for back position operations.
    public enum Back {
        public typealias View = Property<Queue<Element>.DoubleEnded.Back, Queue<Element>.DoubleEnded>.View.Typed<Element>
    }
}

// MARK: - Peek Accessor (Non-Mutating)

extension Queue.DoubleEnded where Element: Copyable {
    /// Accessor for non-mutating peek operations.
    ///
    /// Provides read-only access to front/back elements without requiring
    /// a mutating context.
    public struct PeekAccessor {
        @usableFromInline
        internal let _buffer: Buffer<Element>.Ring

        @inlinable
        internal init(buffer: Buffer<Element>.Ring) {
            self._buffer = buffer
        }

        /// The front element, or `nil` if the deque is empty.
        ///
        /// - Complexity: O(1)
        @inlinable
        public var front: Element? {
            guard !_buffer.isEmpty else { return nil }
            return _buffer.peek.front
        }

        /// The back element, or `nil` if the deque is empty.
        ///
        /// - Complexity: O(1)
        @inlinable
        public var back: Element? {
            guard !_buffer.isEmpty else { return nil }
            return _buffer.peek.back
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
        PeekAccessor(buffer: _buffer)
    }
}

// MARK: - Front Accessor (Property.View.Typed)

extension Queue.DoubleEnded where Element: ~Copyable {
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
    public var front: Front.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Front.View = unsafe .init(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.View.Typed
where Tag == Queue<Element>.DoubleEnded.Front,
      Base == Queue<Element>.DoubleEnded,
      Element: ~Copyable
{
    /// Peeks at the front element without removing it.
    ///
    /// - Parameter body: A closure that borrows the front element.
    /// - Returns: The result of `body`, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek<R: ~Copyable>(_ body: (borrowing Element) -> R) -> R? {
        guard !(unsafe base.value.isEmpty) else { return nil }
        return unsafe base.value._buffer.withFront(body)
    }

    /// Pushes an element to the front of the deque.
    ///
    /// - Parameter element: The element to push.
    /// - Complexity: O(1) amortized
    @inlinable
    public func push(_ element: consuming Element) {
        unsafe base.value._buffer.push.front(consume element)
    }

    /// Removes and returns the front element.
    ///
    /// - Returns: The front element.
    /// - Throws: ``Queue/DoubleEnded/Error/empty`` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public func pop() throws(Queue<Element>.DoubleEnded.Error) -> Element {
        guard !(unsafe base.value.isEmpty) else {
            throw .empty
        }
        return unsafe base.value._buffer.pop.front()
    }

    /// Removes and returns the front element, or nil if empty.
    ///
    /// - Returns: The front element, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public var take: Element? {
        guard !(unsafe base.value.isEmpty) else { return nil }
        return unsafe base.value._buffer.pop.front()
    }
}

// MARK: - Front Peek Convenience (Copyable)

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
        guard !(unsafe base.value.isEmpty) else { return nil }
        return unsafe base.value._buffer.peek.front
    }
}

// MARK: - Back Accessor (Property.View.Typed)

extension Queue.DoubleEnded where Element: ~Copyable {
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
    public var back: Back.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Back.View = unsafe .init(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.View.Typed
where Tag == Queue<Element>.DoubleEnded.Back,
      Base == Queue<Element>.DoubleEnded,
      Element: ~Copyable
{
    /// Peeks at the back element without removing it.
    ///
    /// - Parameter body: A closure that borrows the back element.
    /// - Returns: The result of `body`, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek<R: ~Copyable>(_ body: (borrowing Element) -> R) -> R? {
        guard !(unsafe base.value.isEmpty) else { return nil }
        return unsafe base.value._buffer.withBack(body)
    }

    /// Pushes an element to the back of the deque.
    ///
    /// - Parameter element: The element to push.
    /// - Complexity: O(1) amortized
    @inlinable
    public func push(_ element: consuming Element) {
        unsafe base.value._buffer.push.back(consume element)
    }

    /// Removes and returns the back element.
    ///
    /// - Returns: The back element.
    /// - Throws: ``Queue/DoubleEnded/Error/empty`` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public func pop() throws(Queue<Element>.DoubleEnded.Error) -> Element {
        guard !(unsafe base.value.isEmpty) else {
            throw .empty
        }
        return unsafe base.value._buffer.pop.back()
    }

    /// Removes and returns the back element, or nil if empty.
    ///
    /// - Returns: The back element, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public var take: Element? {
        guard !(unsafe base.value.isEmpty) else { return nil }
        return unsafe base.value._buffer.pop.back()
    }
}

// MARK: - Back Peek Convenience (Copyable)

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
        guard !(unsafe base.value.isEmpty) else { return nil }
        return unsafe base.value._buffer.peek.back
    }
}
