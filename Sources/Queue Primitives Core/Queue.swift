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

public import Buffer_Primitives
public import Buffer_Linked_Primitives
import List_Primitives
public import Index_Primitives
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
@safe
public struct Queue<Element: ~Copyable>: ~Copyable {

    @usableFromInline
    package var _buffer: Buffer<Element>.Ring

    // MARK: - Static (declared here to fix Swift compiler bug with ~Copyable in extensions)

    /// A fixed-capacity, inline-storage FIFO queue with compile-time capacity.
    ///
    /// `Queue.Static` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter. Uses ring buffer semantics for O(1) operations.
    ///
    /// - Note: This type is declared inside `Queue` (not in an extension) due to a
    ///   Swift compiler bug where nested types with value generic parameters declared
    ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
    public struct Static<let capacity: Int>: ~Copyable {
        @usableFromInline
        package var _buffer: Buffer<Element>.Ring.Inline<capacity>

        /// Workaround for Swift compiler bug where deinit element cleanup
        /// fails for ~Copyable structs that contain only value-type properties.
        /// Adding a reference type property (`AnyObject?`) fixes the bug.
        /// See: https://github.com/swiftlang/swift/issues/86652
        @usableFromInline
        var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline queue.
        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Ring.Inline<capacity>()
        }

        // No deinit needed — Storage.Inline.deinit handles element cleanup
    }

    // MARK: - Small (SmallVec-style: inline then spill to heap)

    /// A FIFO queue with small-buffer optimization (SmallVec pattern).
    ///
    /// `Queue.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    /// This provides the performance benefits of inline storage for common cases
    /// while supporting unbounded growth.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var queue = Queue<Int>.Small<4>()  // Inline up to 4 elements
    /// queue.enqueue(1)  // Inline
    /// queue.enqueue(2)  // Inline
    /// queue.enqueue(3)  // Inline
    /// queue.enqueue(4)  // Inline
    /// queue.enqueue(5)  // Spills to heap, moves all elements
    /// ```
    ///
    /// ## Non-Copyable
    ///
    /// `Queue.Small` is unconditionally `~Copyable` (move-only) because it requires
    /// a deinitializer to clean up inline storage.
    ///
    /// - Note: This type is declared inside `Queue` (not in an extension) due to a
    ///   Swift compiler bug where nested types with value generic parameters declared
    ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        @usableFromInline
        package var _buffer: Buffer<Element>.Ring.Small<inlineCapacity>

        /// Creates an empty small queue.
        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Ring.Small<inlineCapacity>()
        }

        // No deinit needed — Storage.Inline.deinit handles element cleanup

        /// Whether the queue is currently using heap storage.
        @inlinable
        public var isSpilled: Bool { _buffer.isSpilled }
    }

    /// A fixed-capacity FIFO queue supporting move-only elements.
    ///
    /// `Queue.Fixed` allocates storage upfront and throws on overflow.
    /// Uses ring buffer semantics for O(1) operations. Use this variant when
    /// capacity is known or in contexts requiring predictable memory behavior
    /// (embedded, real-time).
    ///
    /// ## Example
    ///
    /// ```swift
    /// var queue = try Queue<Int>.Bounded(capacity: 10)
    /// try queue.enqueue(1)
    /// try queue.enqueue(2)
    /// queue.dequeue()     // Optional(1)
    /// queue.peek { $0 }   // Optional(2)
    /// ```
    ///
    /// ## Move-Only Support
    ///
    /// Both the queue and its elements can be `~Copyable`:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// var handles = try Queue<FileHandle>.Bounded(capacity: 5)
    /// try handles.enqueue(FileHandle())
    /// ```
    @safe
    public struct Fixed: ~Copyable {
        @usableFromInline
        package var _buffer: Buffer<Element>.Ring.Bounded

        /// The maximum number of elements the queue can hold.
        public let capacity: Index.Count

        /// Creates a queue with the specified capacity.
        ///
        /// - Parameter capacity: Maximum number of elements.
        @inlinable
        public init(capacity: Index.Count) {
            self._buffer = Buffer<Element>.Ring.Bounded(minimumCapacity: capacity)
            self.capacity = capacity
        }

        // Note: No deinit needed - Storage.Heap handles cleanup
    }

    // MARK: - Queue.Linked
    //
    // Declared inside Queue's body to ensure ~Copyable constraint propagation.
    // Storage types are nested INSIDE Queue.Linked (not external) due to
    // Swift compiler bug [MEM-COPY-006] Category 3: ~Copyable constraints
    // don't propagate to external generic types, even within the same module.

    /// A linked-list based FIFO queue supporting move-only elements.
    ///
    /// `Queue.Linked` uses arena-based linked list storage where nodes are stored
    /// contiguously and reference each other by index. This provides O(1) enqueue
    /// and dequeue with efficient memory locality.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var queue = Queue<Int>.Linked()
    /// queue.enqueue(1)
    /// queue.enqueue(2)
    /// queue.dequeue()     // Optional(1)
    /// queue.peek { $0 }   // Optional(2)
    /// ```
    ///
    /// ## Move-Only Support
    ///
    /// Both the queue and its elements can be `~Copyable`:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// var handles = Queue<FileHandle>.Linked()
    /// handles.enqueue(FileHandle())
    /// ```
    ///
    /// ## Copy-on-Write
    ///
    /// When `Element` is `Copyable`, `Queue.Linked` uses copy-on-write semantics:
    /// copies share storage until mutation.
    @safe
    public struct Linked: ~Copyable {

        @usableFromInline
        package var _buffer: Buffer<Element>.Linked<1>

        /// Creates an empty linked queue.
        @inlinable
        public init() {
            self._buffer = try! .create(capacity: 4)
        }

        /// Creates a queue with reserved capacity.
        ///
        /// - Parameter capacity: Number of elements to reserve space for.
        /// - Throws: ``Linked/Error/invalidCapacity`` if capacity is negative.
        @inlinable
        public init(reservingCapacity capacity: Int) throws(__QueueLinkedError) {
            guard capacity >= 0 else {
                throw .invalidCapacity
            }
            self._buffer = try! .create(capacity: Swift.max(capacity, 4))
        }

        // MARK: - Bounded Variant

        /// A fixed-capacity linked-list FIFO queue.
        ///
        /// `Queue.Linked.Fixed` allocates storage upfront and throws on overflow.
        /// Use this variant when capacity is known or in contexts requiring
        /// predictable memory behavior (embedded, real-time).
        ///
        /// ## Example
        ///
        /// ```swift
        /// var queue = try Queue<Int>.Linked.Fixed(capacity: 10)
        /// try queue.enqueue(1)
        /// try queue.enqueue(2)
        /// queue.dequeue()  // Optional(1)
        /// ```
        @safe
        public struct Fixed: ~Copyable {
            @usableFromInline
            package var _buffer: Buffer<Element>.Linked<1>

            /// The maximum number of elements the queue can hold.
            public let capacity: Index_Primitives.Index<Element>.Count

            /// Creates a queue with the specified capacity.
            ///
            /// - Parameter capacity: Maximum number of elements. Must be positive.
            /// - Throws: ``Bounded/Error/invalidCapacity`` if capacity is not positive.
            @inlinable
            public init(capacity: Index_Primitives.Index<Element>.Count) throws(__QueueLinkedBoundedError) {
                guard capacity > .zero else {
                    throw .invalidCapacity
                }
                self._buffer = try! .create(capacity: capacity.retag())
                self.capacity = capacity
            }
        }
    }

    // MARK: - Queue.DoubleEnded
    //
    // Declared inside Queue's body to ensure ~Copyable constraint propagation.
    // Storage and variant types are nested INSIDE Queue.DoubleEnded for proper naming.
    // Operations are in Queue.DoubleEnded.swift as extensions.

    /// Double-ended queue with O(1) amortized operations at both ends.
    ///
    /// Operations and implementation details are in `Queue.DoubleEnded.swift`.
    @safe
    public struct DoubleEnded {

        @usableFromInline
        package var _buffer: Buffer<Element>.Ring

        /// Which end of the deque to operate on.
        public enum Position: Sendable, Equatable {
            case front
            case back
        }

        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Ring(minimumCapacity: .zero)
        }

        @inlinable
        public init(reservingCapacity capacity: Index.Count) {
            self._buffer = Buffer<Element>.Ring(minimumCapacity: capacity)
        }

        // MARK: - Fixed (nested inside DoubleEnded)

        /// Fixed-capacity double-ended queue.
        ///
        /// Accessed as `Queue<E>.DoubleEnded.Fixed` or via the `Deque.Fixed` typealias.
        @safe
        public struct Fixed {
            @usableFromInline
            package var _buffer: Buffer<Element>.Ring.Bounded

            public let capacity: Index.Count

            @inlinable
            public init(capacity: Index.Count) {
                self._buffer = Buffer<Element>.Ring.Bounded(minimumCapacity: capacity)
                self.capacity = capacity
            }
        }

        // MARK: - Static (inline-storage double-ended queue)

        /// Inline-storage double-ended queue with compile-time capacity.
        ///
        /// `Queue.DoubleEnded.Static` stores elements directly within the struct's memory layout,
        /// requiring no heap allocation. The capacity is specified as a compile-time
        /// generic parameter. Uses ring buffer semantics for O(1) operations at both ends.
        ///
        /// - Note: This type is declared inside `Queue.DoubleEnded` (not via typealias) for
        ///   proper API organization after Swift compiler improvements.
        public struct Static<let capacity: Int>: ~Copyable {
            @usableFromInline
            package var _buffer: Buffer<Element>.Ring.Inline<capacity>

            /// Workaround for Swift compiler bug where deinit element cleanup
            /// fails for ~Copyable structs that contain only value-type properties.
            @usableFromInline
            package var _deinitWorkaround: AnyObject? = nil

            /// Creates an empty inline double-ended queue.
            @inlinable
            public init() {
                self._buffer = Buffer<Element>.Ring.Inline<capacity>()
            }

            // No deinit needed — Storage.Inline.deinit handles element cleanup
        }

        // MARK: - Small (small-buffer optimization double-ended queue)

        /// Small-buffer optimization double-ended queue.
        ///
        /// `Queue.DoubleEnded.Small` stores up to `inlineCapacity` elements in inline storage,
        /// then automatically spills to heap storage when that capacity is exceeded.
        ///
        /// - Note: This type is declared inside `Queue.DoubleEnded` (not via typealias) for
        ///   proper API organization after Swift compiler improvements.
        @safe
        public struct Small<let inlineCapacity: Int>: ~Copyable {
            @usableFromInline
            package var _buffer: Buffer<Element>.Ring.Small<inlineCapacity>

            /// Creates an empty small double-ended queue.
            @inlinable
            public init() {
                self._buffer = Buffer<Element>.Ring.Small<inlineCapacity>()
            }

            // No deinit needed — Storage.Inline/Heap handle element cleanup

            /// Whether the deque is currently using heap storage.
            @inlinable
            public var isSpilled: Bool { _buffer.isSpilled }
        }
    }

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

/// `Queue.Fixed` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Queue.Fixed: Copyable where Element: Copyable {}

// MARK: - Queue.DoubleEnded Copyable Conformances

/// `Queue.DoubleEnded` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Queue.DoubleEnded: Copyable where Element: Copyable {}

/// `Queue.DoubleEnded.Fixed` is `Copyable` when its elements are `Copyable`.
extension Queue.DoubleEnded.Fixed: Copyable where Element: Copyable {}

// Note: Queue.DoubleEnded.Static and Queue.DoubleEnded.Small are UNCONDITIONALLY ~Copyable due to deinit
// Note: Queue.Small and Queue.Static are UNCONDITIONALLY ~Copyable due to deinit requirement

// MARK: - Queue.Linked Copyable Conformances

/// `Queue.Linked` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Queue.Linked: Copyable where Element: Copyable {}

/// `Queue.Linked.Bounded` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Queue.Linked.Fixed: Copyable where Element: Copyable {}

// Note: Queue.Linked.Inline and Queue.Linked.Small are UNCONDITIONALLY ~Copyable due to deinit

// MARK: - Inline and Small Variants (Copyable elements only)
//
// These variants use InlineArray which requires Copyable elements.
// Per [MEM-COPY-006] Category 4, there is no workaround for this limitation.

extension Queue.Linked where Element: Copyable {

    /// A fixed-capacity, inline-storage FIFO queue with compile-time capacity.
    ///
    /// `Queue.Linked.Inline` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var queue = Queue<Int>.Linked.Inline<8>()
    /// try queue.enqueue(1)
    /// try queue.enqueue(2)
    /// queue.dequeue()  // Optional(1)
    /// ```
    ///
    /// ## Non-Copyable Container
    ///
    /// `Inline` is unconditionally `~Copyable` (move-only) even though it requires
    /// `Copyable` elements. This is because it contains inline storage that requires
    /// careful lifecycle management.
    ///
    /// ## Element Requirement
    ///
    /// This variant requires `Element: Copyable` due to InlineArray limitations.
    /// For ~Copyable elements, use ``Queue/Linked`` or ``Queue/Linked/Bounded`` instead.
    public struct Inline<let capacity: Int>: ~Copyable {
        @usableFromInline
        package var _storage: List<Element>.Linked<1>.Inline<capacity>

        /// Creates an empty inline linked queue.
        public init() {
            self._storage = List<Element>.Linked<1>.Inline<capacity>()
        }
    }

    /// A FIFO queue with small-buffer optimization (SmallVec pattern).
    ///
    /// `Queue.Linked.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var queue = Queue<Int>.Linked.Small<4>()  // Inline up to 4 elements
    /// queue.enqueue(1)  // Inline
    /// queue.enqueue(2)  // Inline
    /// queue.enqueue(3)  // Inline
    /// queue.enqueue(4)  // Inline
    /// queue.enqueue(5)  // Spills to heap
    /// ```
    ///
    /// ## Non-Copyable Container
    ///
    /// `Small` is unconditionally `~Copyable` (move-only) even though it requires
    /// `Copyable` elements. This is because it contains inline storage that requires
    /// careful lifecycle management.
    ///
    /// ## Element Requirement
    ///
    /// This variant requires `Element: Copyable` due to InlineArray limitations.
    /// For ~Copyable elements, use ``Queue/Linked`` or ``Queue/Linked/Bounded`` instead.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        @usableFromInline
        package var _storage: List<Element>.Linked<1>.Small<inlineCapacity>

        /// Creates an empty small linked queue.
        public init() {
            self._storage = List<Element>.Linked<1>.Small<inlineCapacity>()
        }

        /// Whether the queue is currently using heap storage.
        public var isSpilled: Bool { _storage.isSpilled }
    }
}

// Note: Queue.Linked.Small and Queue.Linked.Inline are UNCONDITIONALLY ~Copyable due to deinit requirement

// MARK: - Sendable

/// `Queue` is `Sendable` when its elements are `Sendable`.
extension Queue: @unchecked Sendable where Element: Sendable {}

/// `Queue.DoubleEnded` is `Sendable` when its elements are `Sendable`.
extension Queue.DoubleEnded: @unchecked Sendable where Element: Sendable {}

/// `Queue.DoubleEnded.Fixed` is `Sendable` when its elements are `Sendable`.
extension Queue.DoubleEnded.Fixed: @unchecked Sendable where Element: Sendable {}

/// `Queue.DoubleEnded.Static` is `Sendable` when its elements are `Sendable`.
extension Queue.DoubleEnded.Static: @unchecked Sendable where Element: Sendable {}

/// `Queue.DoubleEnded.Small` is `Sendable` when its elements are `Sendable`.
extension Queue.DoubleEnded.Small: @unchecked Sendable where Element: Sendable {}

/// `Queue.Fixed` is `Sendable` when its elements are `Sendable`.
extension Queue.Fixed: @unchecked Sendable where Element: Sendable {}

/// `Queue.Static` is `Sendable` when its elements are `Sendable`.
extension Queue.Static: @unchecked Sendable where Element: Sendable {}

/// `Queue.Small` is `Sendable` when its elements are `Sendable`.
extension Queue.Small: @unchecked Sendable where Element: Sendable {}
