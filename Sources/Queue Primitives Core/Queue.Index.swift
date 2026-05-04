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
public import Index_Primitives

extension Queue where Element: ~Copyable {
    /// Type-safe index for queue elements.
    ///
    /// Uses `Index<Element>` to provide compile-time safety preventing
    /// cross-collection index confusion.
    ///
    /// ## Position Semantics
    ///
    /// Position 0 is the front of the queue (next to be dequeued).
    /// Position `count - 1` is the back (most recently enqueued).
    ///
    /// ## Example
    ///
    /// ```swift
    /// let queueIdx: Queue<Int>.Index = 0
    /// let stackIdx: Stack<Int>.Index = 0
    /// // queueIdx == stackIdx  // Does not compile - different types
    /// ```
    public typealias Index = Index_Primitives.Index<Element>
}

// MARK: - Typed Subscript (Queue, ~Copyable)

extension Queue where Element: ~Copyable {
    /// Accesses the element at the given typed index.
    ///
    /// - Parameter index: The typed index of the element to access (0 = front).
    /// - Precondition: `index.position` must be in `0..<count`.
    @inlinable
    public subscript(index: Index) -> Element {
        _read {
            yield _buffer[index]
        }
        _modify {
            yield &_buffer[index]
        }
    }
}

// Note: Copyable subscript with CoW is in Queue Dynamic Primitives (needs makeUnique)

// MARK: - Safe Access (Queue)

extension Queue where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index < _buffer.count.map(Ordinal.init) else { return nil }
        return _buffer[index]
    }
}

// MARK: - Bounded Queue Index Operations
// NOTE: Per [MEM-COPY-006], Queue.Fixed extensions are in Queue.swift
// to avoid breaking ~Copyable propagation.

// MARK: - Static Queue Index Operations
// NOTE: Per [MEM-COPY-006], Queue.Static extensions are in Queue.swift
// to avoid breaking ~Copyable propagation.
