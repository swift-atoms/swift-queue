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

// MARK: - Input.Streaming Conformance

// Note: Queue.Small is unconditionally ~Copyable due to deinit requirement.
// Input.Streaming conformance requires Element: Copyable for `first: Element?`.

extension Queue.Small: Input.Streaming where Element: Copyable {
    /// The front element, if any.
    ///
    /// Uses `_read` accessor for borrowing semantics per SE-0474 preparation.
    @inlinable
    public var first: Element? {
        _read {
            if _count > 0 {
                if let heap = _heap {
                    yield heap._readElement(at: heap.header.head)
                } else {
                    let ptr = unsafe _inlineReadPointerToElement(at: _head)
                    yield unsafe ptr.pointee
                }
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

extension Queue.Small: Input.`Protocol` where Element: Copyable {
    /// Checkpoint for backtracking: stores head position and count.
    ///
    /// Restoring to a checkpoint moves the logical head pointer back,
    /// effectively "unconsuming" elements. This only works if no elements
    /// have been enqueued since the checkpoint was created.
    ///
    /// > Note: Works correctly whether storage is inline or on heap.
    public struct Checkpoint: Sendable, Comparable {
        /// The head position at checkpoint time (inline or heap).
        @usableFromInline
        let head: Int

        /// The count at checkpoint time.
        @usableFromInline
        let count: Int

        /// Whether heap storage was in use at checkpoint time.
        @usableFromInline
        let wasOnHeap: Bool

        @usableFromInline
        init(head: Int, count: Int, wasOnHeap: Bool) {
            self.head = head
            self.count = count
            self.wasOnHeap = wasOnHeap
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
        if let heap = _heap {
            return Checkpoint(head: heap.header.head, count: _count, wasOnHeap: true)
        } else {
            return Checkpoint(head: _head, count: _count, wasOnHeap: false)
        }
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
        if checkpoint.wasOnHeap {
            // Restore heap header
            guard let heap = _heap else {
                preconditionFailure("Checkpoint was on heap but queue is now inline")
            }
            heap.header.head = checkpoint.head
            heap.header.count = checkpoint.count
        } else {
            // Restore inline state
            _head = checkpoint.head
        }
        _count = checkpoint.count
    }

    /// Advances cursor by `n` elements.
    ///
    /// - Parameter n: The number of elements to skip.
    /// - Precondition: `n >= 0` and `n <= count`.
    @inlinable
    public mutating func advance(by n: Int) {
        precondition(n >= 0 && n <= count, "Cannot advance by more elements than available")
        for _ in 0..<n {
            _ = dequeue()
        }
    }
}
