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

import List_Primitives
public import Index_Primitives
import Range_Primitives

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

    // MARK: - Unified Storage (nested to inherit Element's ~Copyable context)

    /// Header for ring buffer storage with typed indices.
    ///
    /// Uses `Index<Element>` for physical buffer positions and `Index<Element>.Count`
    /// for element count, providing type safety across the queue implementation.
    @usableFromInline
    package struct Header {
        /// Physical position of next element to dequeue.
        @usableFromInline package var head: Index_Primitives.Index<Element>
        /// Physical position where next element will be enqueued.
        @usableFromInline package var tail: Index_Primitives.Index<Element>
        /// Number of valid elements in the buffer.
        @usableFromInline package var count: Index_Primitives.Index<Element>.Count

        /// Creates a header with all positions at zero.
        @inlinable
        init() {
            self.head = .zero
            self.tail = .zero
            self.count = .zero
        }

        /// Creates a header with the specified values.
        @inlinable
        init(head: Index_Primitives.Index<Element>, tail: Index_Primitives.Index<Element>, count: Index_Primitives.Index<Element>.Count) {
            self.head = head
            self.tail = tail
            self.count = count
        }
    }

    /// Internal storage class for ring buffer-based queues.
    ///
    /// Uses `ManagedBuffer` for efficient single-allocation storage.
    /// Header stores (head, tail, count) for ring buffer management.
    /// Declared as a nested class inside `Queue` so that the `Element` generic
    /// inherits the `~Copyable` suppression from the outer type.
    ///
    /// Ring buffer semantics:
    /// - `head`: Index of next element to dequeue
    /// - `tail`: Index where next element will be enqueued
    /// - `count`: Number of valid elements
    ///
    /// - Note: This must be nested, not module-level, due to Swift's generic
    ///   constraint propagation limitations with `~Copyable` and nested types.
    @usableFromInline
    package final class Storage: ManagedBuffer<Header, Element> {

        /// Creates empty storage with no capacity.
        @usableFromInline
        static func create() -> Storage {
            let storage = Storage.create(minimumCapacity: 0) { _ in Header() }
            return unsafe unsafeDowncast(storage, to: Storage.self)
        }

        /// Creates storage with the specified minimum capacity.
        @usableFromInline
        static func create(minimumCapacity: Int) -> Storage {
            let storage = Storage.create(minimumCapacity: minimumCapacity) { _ in Header() }
            return unsafe unsafeDowncast(storage, to: Storage.self)
        }

        deinit {
            guard header.count > 0 else { return }
            var physicalIndex = header.head.position.rawValue
            _ = unsafe withUnsafeMutablePointerToElements { ptr in
                for _ in 0..<header.count {
                    unsafe (ptr + physicalIndex).deinitialize(count: 1)
                    physicalIndex = (physicalIndex + 1) % capacity
                }
            }
        }

        /// Returns the elements pointer.
        @usableFromInline
        package var _elementsPointer: UnsafeMutablePointer<Element> {
            unsafe withUnsafeMutablePointerToElements { unsafe $0 }
        }
    }

    @usableFromInline
    package var _storage: Storage

    /// Cached pointer to element storage. Stored in struct to enable property-based Span access.
    /// CRITICAL: Must be updated whenever _storage is replaced (reallocation, CoW copy).
    @usableFromInline
    package var _cachedPtr: UnsafeMutablePointer<Element>

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
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        static var _maxStride: Int { 64 }

        /// Raw byte storage. Each slot is 64 bytes (8 Ints on 64-bit).
        @usableFromInline
        package var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Ring buffer head index (next dequeue position).
        @usableFromInline
        package var _head: Int

        /// Ring buffer tail index (next enqueue position).
        @usableFromInline
        package var _tail: Int

        /// Current element count.
        @usableFromInline
        package var _count: Int

        /// Workaround for Swift compiler bug where deinit element cleanup
        /// fails for ~Copyable structs that contain only value-type properties.
        /// Adding a reference type property (`AnyObject?`) fixes the bug.
        /// See: https://github.com/swiftlang/swift/issues/86652
        @usableFromInline
        var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline queue.
        @inlinable
        public init() {
            precondition(
                MemoryLayout<Element>.stride <= Self._maxStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self._maxStride) bytes). Use Queue.Bounded instead."
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment)). Use Queue.Bounded instead."
            )
            self._storage = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
            self._head = 0
            self._tail = 0
            self._count = 0
        }

        deinit {
            let count = _count
            guard count > 0 else { return }

            // Workaround: Copy storage state to local vars before cleanup.
            // The _storage access through withUnsafeBytes may be optimized incorrectly
            // for ~Copyable structs without reference type properties.
            let head = _head
            let stride = MemoryLayout<Element>.stride

            unsafe Swift.withUnsafePointer(to: _storage) { storagePtr in
                let basePtr = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(storagePtr))
                for i in 0..<count {
                    let physicalIndex = (head + i) % Self.capacity
                    let elementPtr = unsafe (basePtr + physicalIndex * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
        }
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
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        static var _maxStride: Int { 64 }

        /// Raw byte storage for inline elements. Each slot is 64 bytes (8 Ints on 64-bit).
        @usableFromInline
        package var _inline: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Ring buffer head index (inline mode only).
        @usableFromInline
        package var _head: Int

        /// Ring buffer tail index (inline mode only).
        @usableFromInline
        package var _tail: Int

        /// Current element count (valid in both inline and heap modes).
        @usableFromInline
        package var _count: Int

        /// Heap storage when spilled. Nil when using inline storage.
        @usableFromInline
        package var _heap: Storage?

        /// Cached pointer to heap elements. Only valid when _heap is non-nil.
        @usableFromInline
        package var _heapPtr: UnsafeMutablePointer<Element>?

        /// Creates an empty small queue.
        @inlinable
        public init() {
            precondition(
                MemoryLayout<Element>.stride <= Self._maxStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self._maxStride) bytes). Use Queue.Bounded instead."
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment)). Use Queue.Bounded instead."
            )
            self._inline = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
            self._head = 0
            self._tail = 0
            self._count = 0
            self._heap = nil
            unsafe (self._heapPtr = nil)
        }

        deinit {
            let count = _count
            guard count > 0 else { return }

            if let heap = _heap {
                // Elements are on heap - Storage handles cleanup via its deinit
                // Set header count for proper cleanup
                heap.header.count = Index_Primitives.Index<Element>.Count(__unchecked: count)
            } else {
                // Elements are inline - clean up manually using ring buffer order
                let stride = MemoryLayout<Element>.stride
                var index = _head
                unsafe Swift.withUnsafeBytes(of: _inline) { bytes in
                    let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for _ in 0..<count {
                        let elementPtr = unsafe (basePtr + index * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe elementPtr.deinitialize(count: 1)
                        index = (index + 1) % inlineCapacity
                    }
                }
            }
        }

        /// Whether the queue is currently using heap storage.
        @inlinable
        public var isSpilled: Bool { _heap != nil }
    }

    /// A fixed-capacity FIFO queue supporting move-only elements.
    ///
    /// `Queue.Bounded` allocates storage upfront and throws on overflow.
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
    public struct Bounded: ~Copyable {
        @usableFromInline
        package var _storage: Storage  // Uses unified nested storage class

        /// Cached pointer to element storage. Stored in struct to enable property-based Span access.
        /// CRITICAL: Must be updated whenever _storage is replaced (CoW copy).
        @usableFromInline
        package var _cachedPtr: UnsafeMutablePointer<Element>

        /// The maximum number of elements the queue can hold.
        public let capacity: Int

        /// Creates a queue with the specified capacity.
        ///
        /// - Parameter capacity: Maximum number of elements. Must be non-negative.
        /// - Throws: ``Queue/Bounded/Error/invalidCapacity`` if capacity is negative.
        @inlinable
        public init(capacity: Int) throws(Queue<Element>.Bounded.Error) {
            guard capacity >= 0 else {
                throw .invalidCapacity
            }

            self._storage = Storage.create(minimumCapacity: capacity)
            unsafe (self._cachedPtr = _storage._elementsPointer)
            self.capacity = capacity
        }

        // Note: No deinit needed - Storage handles cleanup
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

        // ============================================================================
        // MARK: - Nested Storage Types
        // ============================================================================
        // These types MUST be nested inside Queue.Linked to inherit the ~Copyable
        // constraint suppression from Element. Moving them outside fails due to
        // [MEM-COPY-006] Category 3.

        /// Header for arena-based linked list storage.
        @usableFromInline
        package struct Header {
            @usableFromInline package var head: Int
            @usableFromInline package var tail: Int
            @usableFromInline package var freeHead: Int
            @usableFromInline package var count: Int
            @usableFromInline package var capacity: Int

            @usableFromInline
            package init() {
                self.head = -1
                self.tail = -1
                self.freeHead = -1
                self.count = 0
                self.capacity = 0
            }
        }

        /// A node in the arena-based linked list.
        @frozen
        @usableFromInline
        package struct Node: ~Copyable {
            @usableFromInline package var element: Element
            @usableFromInline package var nextIndex: Int

            @usableFromInline
            package init(element: consuming Element, nextIndex: Int) {
                self.element = element
                self.nextIndex = nextIndex
            }
        }

        /// Internal storage class for arena-based linked list.
        @usableFromInline
        package final class Storage: ManagedBuffer<Header, Node> {

            @usableFromInline
            package static func create() -> Storage {
                let storage = Storage.create(minimumCapacity: 0) { _ in Header() }
                return unsafe unsafeDowncast(storage, to: Storage.self)
            }

            @usableFromInline
            package static func create(minimumCapacity: Int) -> Storage {
                var header = Header()
                header.capacity = minimumCapacity
                let storage = Storage.create(minimumCapacity: minimumCapacity) { _ in header }
                return unsafe unsafeDowncast(storage, to: Storage.self)
            }

            deinit {
                let count = header.count
                guard count > 0 else { return }
                var index = header.head
                _ = unsafe withUnsafeMutablePointerToElements { nodes in
                    while index >= 0 {
                        let nextIndex = unsafe nodes[index].nextIndex
                        unsafe (nodes + index).deinitialize(count: 1)
                        index = nextIndex
                    }
                }
            }
        }

        // ============================================================================
        // MARK: - Properties
        // ============================================================================

        @usableFromInline
        package var _storage: Storage

        /// Creates an empty linked queue.
        @inlinable
        public init() {
            self._storage = Storage.create()
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
            if capacity == 0 {
                self._storage = Storage.create()
            } else {
                self._storage = Storage.create(minimumCapacity: capacity)
            }
        }

        // MARK: - Bounded Variant

        /// A fixed-capacity linked-list FIFO queue.
        ///
        /// `Queue.Linked.Bounded` allocates storage upfront and throws on overflow.
        /// Use this variant when capacity is known or in contexts requiring
        /// predictable memory behavior (embedded, real-time).
        ///
        /// ## Example
        ///
        /// ```swift
        /// var queue = try Queue<Int>.Linked.Bounded(capacity: 10)
        /// try queue.enqueue(1)
        /// try queue.enqueue(2)
        /// queue.dequeue()  // Optional(1)
        /// ```
        @safe
        public struct Bounded: ~Copyable {
            @usableFromInline
            package var _storage: Storage

            /// The maximum number of elements the queue can hold.
            public let capacity: Int

            /// Creates a queue with the specified capacity.
            ///
            /// - Parameter capacity: Maximum number of elements. Must be non-negative.
            /// - Throws: ``Bounded/Error/invalidCapacity`` if capacity is negative.
            @inlinable
            public init(capacity: Int) throws(__QueueLinkedBoundedError) {
                guard capacity >= 0 else {
                    throw .invalidCapacity
                }
                self._storage = Storage.create(minimumCapacity: capacity)
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
    /// Note: Not marked `: ~Copyable` - Swift infers it from Storage which holds Element.
    /// Conditional Copyable conformance is declared separately.
    @safe
    public struct DoubleEnded {

        // MARK: - Storage (typealias to unified Queue.Storage)

        /// Storage typealias for API naming as `Queue.DoubleEnded.Storage`.
        ///
        /// Uses the unified `Queue.Storage` which supports both single-ended
        /// and double-ended operations. This eliminates code duplication
        /// while preserving the expected type name.
        @usableFromInline
        package typealias Storage = Queue<Element>.Storage

        @usableFromInline
        package var _storage: Storage

        /// Which end of the deque to operate on.
        public enum Position: Sendable, Equatable {
            case front
            case back
        }

        @inlinable
        public init() {
            self._storage = Storage.create()
        }

        @inlinable
        public init(reservingCapacity capacity: Int) throws(__QueueDoubleEndedError) {
            guard capacity >= 0 else { throw .invalidCapacity }
            self._storage = Storage.create(minimumCapacity: capacity)
        }

        // MARK: - Fixed (nested inside DoubleEnded)

        /// Fixed-capacity double-ended queue.
        ///
        /// Accessed as `Queue<E>.DoubleEnded.Fixed` or via the `Deque.Fixed` typealias.
        @safe
        public struct Fixed {
            @usableFromInline
            package var _storage: Storage

            public let capacity: Int

            @inlinable
            public init(capacity: Int) throws(__QueueDoubleEndedFixedError) {
                guard capacity >= 0 else { throw .invalidCapacity }
                self._storage = Storage.create(minimumCapacity: capacity)
                self.capacity = capacity
            }
        }

        // MARK: - Static (typealias to Queue-level type)

        /// Inline-storage double-ended queue with compile-time capacity.
        ///
        /// Accessed as `Queue<E>.DoubleEnded.Static<N>` or via the `Deque.Static` typealias.
        /// Implemented at Queue level due to Swift's ~Copyable constraint propagation limitations.
        public typealias Static<let capacity: Int> = _DoubleEndedStatic<capacity>

        // MARK: - Small (typealias to Queue-level type)

        /// Small-buffer optimization double-ended queue.
        ///
        /// Accessed as `Queue<E>.DoubleEnded.Small<N>` or via the `Deque.Small` typealias.
        /// Implemented at Queue level due to Swift's ~Copyable constraint propagation limitations.
        public typealias Small<let inlineCapacity: Int> = _DoubleEndedSmall<inlineCapacity>
    }

    // MARK: - _DoubleEndedStatic (Queue-level implementation)

    /// Internal implementation for `Queue.DoubleEnded.Static`.
    ///
    /// Declared at Queue level (not inside DoubleEnded) because Swift's ~Copyable
    /// constraint propagation doesn't work at deeper nesting levels.
    /// Access via `Queue<E>.DoubleEnded.Static<N>` typealias.
    public struct _DoubleEndedStatic<let capacity: Int>: ~Copyable {
        @usableFromInline
        package static var _maxStride: Int { 64 }

        @usableFromInline
        package var _head: Int

        @usableFromInline
        package var _count: Int

        @usableFromInline
        package var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        @usableFromInline
        package var _deinitWorkaround: AnyObject? = nil

        @inlinable
        public init() {
            precondition(MemoryLayout<Element>.stride <= Self._maxStride)
            precondition(MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment)
            self._head = 0
            self._count = 0
            self._storage = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
        }

        deinit {
            let count = _count
            guard count > 0 else { return }
            let stride = MemoryLayout<Element>.stride
            var index = _head
            unsafe Swift.withUnsafeBytes(of: _storage) { bytes in
                let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                for _ in 0..<count {
                    let elementPtr = unsafe (basePtr + index * stride).assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                    index = (index + 1) % capacity
                }
            }
        }
    }

    // MARK: - _DoubleEndedSmall (Queue-level implementation)

    /// Internal implementation for `Queue.DoubleEnded.Small`.
    ///
    /// Declared at Queue level (not inside DoubleEnded) because Swift's ~Copyable
    /// constraint propagation doesn't work at deeper nesting levels.
    /// Access via `Queue<E>.DoubleEnded.Small<N>` typealias.
    @safe
    public struct _DoubleEndedSmall<let inlineCapacity: Int>: ~Copyable {
        @usableFromInline
        package static var _maxStride: Int { 64 }

        @usableFromInline
        package var _head: Int

        @usableFromInline
        package var _count: Int

        @usableFromInline
        package var _inline: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        @usableFromInline
        package var _heap: Storage?

        @inlinable
        public init() {
            precondition(MemoryLayout<Element>.stride <= Self._maxStride)
            precondition(MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment)
            self._head = 0
            self._count = 0
            self._inline = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
            self._heap = nil
        }

        deinit {
            let count = _count
            guard count > 0 else { return }
            if let heap = _heap {
                heap.header.count = Index_Primitives.Index<Element>.Count(__unchecked: count)
            } else {
                let stride = MemoryLayout<Element>.stride
                unsafe Swift.withUnsafeBytes(of: _inline) { bytes in
                    let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in 0..<count {
                        let physicalIndex = (_head + i) % inlineCapacity
                        let elementPtr = unsafe (basePtr + physicalIndex * stride).assumingMemoryBound(to: Element.self)
                        unsafe elementPtr.deinitialize(count: 1)
                    }
                }
            }
        }
    }

    /// Creates an empty queue.
    ///
    /// No allocation occurs until the first enqueue.
    @inlinable
    public init() {
        self._storage = Storage.create()
        unsafe (self._cachedPtr = _storage._elementsPointer)
    }

    /// Creates a queue with reserved capacity.
    ///
    /// Pre-allocates storage for the specified number of elements.
    /// Useful when the approximate number of elements is known.
    ///
    /// - Parameter capacity: Number of elements to reserve space for. Must be non-negative.
    /// - Throws: ``Queue/Error/invalidCapacity`` if capacity is negative.
    @inlinable
    public init(reservingCapacity capacity: Int) throws(Queue<Element>.Error) {
        guard capacity >= 0 else {
            throw .invalidCapacity
        }

        if capacity == 0 {
            self._storage = Storage.create()
        } else {
            self._storage = Storage.create(minimumCapacity: capacity)
        }
        unsafe (self._cachedPtr = _storage._elementsPointer)
    }

    // Note: No deinit needed - Storage handles cleanup
}

// MARK: - Conditional Copyable

/// `Queue` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Queue: Copyable where Element: Copyable {}

/// `Queue.Bounded` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Queue.Bounded: Copyable where Element: Copyable {}

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
extension Queue.Linked.Bounded: Copyable where Element: Copyable {}

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
extension Queue._DoubleEndedStatic: @unchecked Sendable where Element: Sendable {}

/// `Queue.DoubleEnded.Small` is `Sendable` when its elements are `Sendable`.
extension Queue._DoubleEndedSmall: @unchecked Sendable where Element: Sendable {}

/// `Queue.Bounded` is `Sendable` when its elements are `Sendable`.
extension Queue.Bounded: @unchecked Sendable where Element: Sendable {}

/// `Queue.Static` is `Sendable` when its elements are `Sendable`.
extension Queue.Static: @unchecked Sendable where Element: Sendable {}

/// `Queue.Small` is `Sendable` when its elements are `Sendable`.
extension Queue.Small: @unchecked Sendable where Element: Sendable {}
