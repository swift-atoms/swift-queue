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

public import Buffer_Ring_Primitives
public import Input_Primitives
public import Queue_Primitives_Core

// MARK: - Input.Streaming Conformance

extension Queue.Fixed: Input.Streaming where Element: Copyable {
    /// The front element, if any.
    ///
    /// Uses `_read` accessor for borrowing semantics per SE-0474 preparation.
    @inlinable
    public var first: Element? {
        _read {
            yield peek()
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

extension Queue.Fixed: Input.`Protocol` where Element: Copyable {
    /// Checkpoint for backtracking.
    ///
    /// Restoring to a checkpoint "unconsumes" elements by adjusting the
    /// ring buffer head pointer. This only works if no elements have been
    /// enqueued since the checkpoint was created.
    public typealias Checkpoint = Buffer<Element>.Ring.Checkpoint

    /// Creates a checkpoint at the current position.
    @inlinable
    public var checkpoint: Checkpoint {
        _buffer.checkpoint
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
        _buffer.ensureUnique()
        _buffer.restore(to: checkpoint)
    }

    /// Advances cursor by `n` elements.
    ///
    /// - Parameter n: The number of elements to skip.
    /// - Precondition: `n <= count`.
    @inlinable
    public mutating func advance(by n: Index_Primitives.Index<Element>.Count) {
        precondition(n <= count, "Cannot advance by more elements than available")
        var i: Index_Primitives.Index<Element>.Count = .zero
        while i < n {
            _ = dequeue()
            i += .one
        }
    }
}
