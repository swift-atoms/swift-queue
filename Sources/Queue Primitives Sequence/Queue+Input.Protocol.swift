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

public import Input_Primitives
import Queue_Dynamic_Primitives

// MARK: - Input.Streaming Conformance

extension Queue: Input.Streaming where Element: Copyable {
    /// The front element, if any.
    ///
    /// Uses `_read` accessor for borrowing semantics per SE-0474 preparation.
    @inlinable
    public var first: Element? {
        _read {
            if _storage.header.count > 0 {
                yield _storage._readElement(at: _storage.header.head.position)
            } else {
                yield nil
            }
        }
    }

    /// Advances the cursor, returning the consumed element.
    ///
    /// - Returns: The consumed element.
    /// - Throws: ``Input/Stream/Error/empty`` if the queue is empty.
    @inlinable
    @discardableResult
    public mutating func advance() throws(Input.Stream.Error) -> Element {
        guard let element = dequeue() else {
            throw .empty
        }
        return element
    }
}

// MARK: - Input.Protocol Conformance

extension Queue: Input.`Protocol` where Element: Copyable {
    /// Checkpoint for backtracking: stores head index and count.
    ///
    /// Restoring to a checkpoint moves the logical head pointer back,
    /// effectively "unconsuming" elements. This only works if no elements
    /// have been enqueued since the checkpoint was created.
    ///
    /// > Note: The ring buffer preserves dequeued elements until
    /// > they are overwritten by new enqueues, enabling checkpoint/restore.
    public struct Checkpoint: Sendable, Comparable {
        /// The head index at checkpoint time.
        @usableFromInline
        let head: Int

        /// The count at checkpoint time.
        @usableFromInline
        let count: Int

        @usableFromInline
        init(head: Int, count: Int) {
            self.head = head
            self.count = count
        }

        @inlinable
        public static func < (lhs: Checkpoint, rhs: Checkpoint) -> Bool {
            // Earlier checkpoints have higher counts (less consumed)
            lhs.count > rhs.count
        }
    }

    /// Creates a checkpoint at the current position.
    @inlinable
    public var checkpoint: Checkpoint {
        Checkpoint(
            head: _storage.header.head.position,
            count: _storage.header.count
        )
    }

    /// The range of valid checkpoint positions.
    ///
    /// > Note: Checkpoints are invalidated by `enqueue()` operations.
    @inlinable
    public var checkpointRange: ClosedRange<Checkpoint> {
        checkpoint...checkpoint
    }

    /// Sets position to a checkpoint.
    ///
    /// - Parameter checkpoint: A checkpoint obtained from ``checkpoint``.
    /// - Precondition: The checkpoint was created from this queue instance and
    ///   no elements have been enqueued since the checkpoint was taken.
    @inlinable
    public mutating func setPosition(to checkpoint: Checkpoint) {
        makeUnique()
        _storage.header.head = checkpoint.head
        _storage.header.count = checkpoint.count
    }

    /// Advances cursor by `n` elements.
    ///
    /// - Parameter n: The number of elements to skip.
    /// - Precondition: `n >= 0` and `n <= count`.
    @inlinable
    public mutating func advance(by n: Int) {
        precondition(n >= 0 && n <= count, "Cannot advance by more elements than available")
        makeUnique()
        for _ in 0..<n {
            _ = dequeue()
        }
    }
}
