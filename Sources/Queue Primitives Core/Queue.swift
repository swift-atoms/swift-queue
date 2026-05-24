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

public import Buffer_Ring_Primitive
public import Buffer_Ring_Primitives
internal import Buffer_Linked_Primitives
internal import Index_Primitives
import List_Primitives_Core
import Vector_Primitives

/// A dynamically-growing FIFO queue supporting move-only elements.
///
/// `Queue` is the general-purpose queue primitive. It provides O(1) amortized enqueue
/// and O(1) dequeue with automatic capacity growth using a ring buffer. This is the
/// canonical queue type - use it unless you have specific constraints requiring a variant.
///
/// ## Example
///
/// ```swift
/// var queue = Queue<Int>()
/// queue.enqueue(1)
/// queue.enqueue(2)
/// queue.dequeue()     // Optional(1)
/// queue.peek { $0 }   // Optional(2)
/// ```
///
/// ## Variants
///
/// - ``Queue``: Dynamically-growing with amortized O(1) enqueue (this type)
/// - ``Queue/Bounded``: Fixed-capacity ring buffer, throws on overflow
/// - ``Queue/Static``: Zero-allocation inline storage with compile-time capacity
/// - ``Queue/Small``: Inline storage with automatic spill to heap
///
/// ## Ring Buffer Storage
///
/// Queue uses a ring buffer internally. Elements wrap around when reaching the
/// end of the buffer, providing efficient O(1) operations without element shifts.
///
/// ## Move-Only Support
///
/// Both the queue and its elements can be `~Copyable`:
///
/// ```swift
/// struct FileHandle: ~Copyable { ... }
/// var handles = Queue<FileHandle>()
/// handles.enqueue(FileHandle())
/// ```
///
/// ## Sequence Conformance
///
/// When `Element` is `Copyable`, `Queue` conforms to `Sequence`:
///
/// ```swift
/// var queue = Queue<Int>()
/// queue.enqueue(1)
/// queue.enqueue(2)
/// for element in queue {
///     print(element)  // 1, then 2
/// }
/// ```
///
/// For `~Copyable` elements, use ``forEach(_:)`` instead.
///
/// ## Copy-on-Write
///
/// When `Element` is `Copyable`, `Queue` uses copy-on-write semantics:
/// copies share storage until mutation, providing efficient value semantics.
///
/// ## Growth Behavior
///
/// When capacity is exceeded, the queue allocates new storage at 2x the
/// current capacity (minimum 4) and moves all elements. This provides
/// O(1) amortized enqueue with approximately 2.0 copies per element over
/// the queue's lifetime.
// WHY: Category D — structural Sendable workaround; the type is
// WHY: structurally value-safe but the compiler cannot synthesize
// WHY: Sendable due to a stored pointer / generic parameter shape.
@safe
public struct Queue<Element: ~Copyable>: ~Copyable {

    @usableFromInline
    package var _buffer: Buffer<Element>.Ring

    /// Creates an empty queue.
    ///
    /// No allocation occurs until the first enqueue.
    @inlinable
    public init() {
        self._buffer = Buffer<Element>.Ring(minimumCapacity: .zero)
    }

    /// Creates a queue with reserved capacity.
    ///
    /// Pre-allocates storage for the specified number of elements.
    /// Useful when the approximate number of elements is known.
    ///
    /// - Parameter capacity: Number of elements to reserve space for.
    @inlinable
    public init(reservingCapacity capacity: Index.Count) {
        self._buffer = Buffer<Element>.Ring(minimumCapacity: capacity)
    }

    // Note: No deinit needed - Storage.Heap handles cleanup
}

// MARK: - Conditional Copyable

/// `Queue` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Queue: Copyable where Element: Copyable {}

// Note: Queue.Small and Queue.Static are UNCONDITIONALLY ~Copyable due to deinit requirement

// MARK: - Sendable

/// `Queue` is `Sendable` when its elements are `Sendable`.
extension Queue: @unchecked Sendable where Element: Sendable {}
