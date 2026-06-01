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

public import Queue_Primitive

extension Queue where Element: ~Copyable {
    /// A result builder for declaratively constructing queues.
    ///
    /// **FIFO semantics.** Declaration order is enqueue order, which is
    /// also dequeue order:
    ///
    /// ```swift
    /// var queue = Queue<Int> {
    ///     1
    ///     2
    ///     3
    /// }
    /// queue.dequeue()  // 1 — first enqueued
    /// queue.dequeue()  // 2
    /// queue.dequeue()  // 3 — last enqueued
    /// ```
    ///
    /// Supports `~Copyable` elements via consuming enqueue:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// let queue: Queue<FileHandle> = Queue<FileHandle> {
    ///     FileHandle()
    ///     FileHandle()
    /// }
    /// ```
    ///
    /// ## `for` Loops Not Supported
    ///
    /// `buildArray` is omitted because Swift's result-builder transform's
    /// buildArray step uses `Swift.Array<Component>`, which currently
    /// requires `Component: Copyable`. The component here is the
    /// ~Copyable `Queue<Element>`.
    @resultBuilder
    public enum Builder {

        // MARK: - Expression Building

        @inlinable
        public static func buildExpression(
            _ expression: consuming Element
        ) -> Queue<Element> {
            var result = Queue<Element>()
            result.enqueue(consume expression)
            return result
        }

        @inlinable
        public static func buildExpression(
            _ expression: consuming Queue<Element>
        ) -> Queue<Element> {
            consume expression
        }

        @inlinable
        public static func buildExpression(
            _ expression: consuming Element?
        ) -> Queue<Element> {
            var result = Queue<Element>()
            if let value = consume expression {
                result.enqueue(consume value)
            }
            return result
        }

        // MARK: - Partial Block Building

        @inlinable
        public static func buildPartialBlock(
            first: consuming Queue<Element>
        ) -> Queue<Element> {
            consume first
        }

        @inlinable
        public static func buildPartialBlock(
            first: Void
        ) -> Queue<Element> {
            Queue<Element>()
        }

        @inlinable
        public static func buildPartialBlock(
            first: Never
        ) -> Queue<Element> {}

        @inlinable
        public static func buildPartialBlock(
            accumulated: consuming Queue<Element>,
            next: consuming Queue<Element>
        ) -> Queue<Element> {
            var result = consume accumulated
            var rest = consume next
            while let element = rest.dequeue() {
                result.enqueue(consume element)
            }
            return result
        }

        // MARK: - Block Building

        @inlinable
        public static func buildBlock() -> Queue<Element> {
            Queue<Element>()
        }

        // MARK: - Control Flow

        @inlinable
        public static func buildOptional(
            _ component: consuming Queue<Element>?
        ) -> Queue<Element> {
            if let result = consume component {
                return consume result
            }
            return Queue<Element>()
        }

        @inlinable
        public static func buildEither(
            first: consuming Queue<Element>
        ) -> Queue<Element> {
            consume first
        }

        @inlinable
        public static func buildEither(
            second: consuming Queue<Element>
        ) -> Queue<Element> {
            consume second
        }

        // buildArray omitted: see DocC above.

        @inlinable
        public static func buildLimitedAvailability(
            _ component: consuming Queue<Element>
        ) -> Queue<Element> {
            consume component
        }
    }
}

// MARK: - Convenience Init

extension Queue where Element: ~Copyable {
    /// Constructs a queue from a result-builder closure.
    ///
    /// FIFO: declaration order = enqueue order = dequeue order.
    ///
    /// ```swift
    /// var queue = Queue<Int> {
    ///     1
    ///     2
    ///     3
    /// }
    /// queue.dequeue()  // 1 (first enqueued)
    /// ```
    @inlinable
    public init(@Queue.Builder _ builder: () -> Self) {
        self = builder()
    }
}

// MARK: - Sequence Bulk-Add (Copyable Element only)

extension Queue.Builder where Element: Copyable {
    /// Bulk-enqueue a Swift.Sequence without per-iteration allocation.
    /// FIFO: iteration order = enqueue order.
    @inlinable
    public static func buildExpression<S: Swift.Sequence>(_ expression: S) -> Queue<Element>
    where S.Element == Element {
        var result = Queue<Element>()
        for value in expression {
            result.enqueue(value)
        }
        return result
    }
}
