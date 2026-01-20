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
/// - ``Queue/Inline``: Zero-allocation inline storage with compile-time capacity
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
    final class Storage: ManagedBuffer<(head: Int, tail: Int, count: Int), Element> {

        /// Creates empty storage with no capacity.
        @usableFromInline
        static func create() -> Storage {
            let storage = Storage.create(minimumCapacity: 0) { _ in (head: 0, tail: 0, count: 0) }
            return unsafe unsafeDowncast(storage, to: Storage.self)
        }

        /// Creates storage with the specified minimum capacity.
        @usableFromInline
        static func create(minimumCapacity: Int) -> Storage {
            let storage = Storage.create(minimumCapacity: minimumCapacity) { _ in (head: 0, tail: 0, count: 0) }
            return unsafe unsafeDowncast(storage, to: Storage.self)
        }

        deinit {
            let count = header.count
            guard count > 0 else { return }
            let cap = capacity
            var index = header.head
            _ = unsafe withUnsafeMutablePointerToElements { elements in
                for _ in 0..<count {
                    unsafe (elements + index).deinitialize(count: 1)
                    index = (index + 1) % cap
                }
            }
        }

        /// Returns pointer to element storage.
        @usableFromInline
        var _elementsPointer: UnsafeMutablePointer<Element> {
            unsafe withUnsafeMutablePointerToElements { unsafe $0 }
        }

        /// Initializes element at the given index.
        @usableFromInline
        func _initializeElement(at index: Int, to element: consuming Element) {
            let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
            unsafe ptr.initialize(to: element)
        }

        /// Moves element from the given index.
        @usableFromInline
        func _moveElement(at index: Int) -> Element {
            unsafe withUnsafeMutablePointerToElements { elements in
                unsafe (elements + index).move()
            }
        }

        /// Deinitializes elements in ring buffer order from head.
        @usableFromInline
        func _deinitializeAllElements() {
            let count = header.count
            guard count > 0 else { return }
            let cap = capacity
            var index = header.head
            _ = unsafe withUnsafeMutablePointerToElements { elements in
                for _ in 0..<count {
                    unsafe (elements + index).deinitialize(count: 1)
                    index = (index + 1) % cap
                }
            }
        }

        /// Moves all elements to new storage, linearizing the ring buffer.
        @usableFromInline
        func _moveAllElements(to newStorage: Storage) {
            let count = header.count
            guard count > 0 else { return }
            let cap = capacity
            var srcIndex = header.head
            _ = unsafe withUnsafeMutablePointerToElements { src in
                unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                    for dstIndex in 0..<count {
                        unsafe (dst + dstIndex).initialize(to: (src + srcIndex).move())
                        srcIndex = (srcIndex + 1) % cap
                    }
                }
            }
        }
    }

    @usableFromInline
    var _storage: Storage

    /// Cached pointer to element storage. Stored in struct to enable property-based Span access.
    /// CRITICAL: Must be updated whenever _storage is replaced (reallocation, CoW copy).
    @usableFromInline
    var _cachedPtr: UnsafeMutablePointer<Element>

    // MARK: - Inline (declared here to fix Swift compiler bug with ~Copyable in extensions)

    /// A fixed-capacity, inline-storage FIFO queue with compile-time capacity.
    ///
    /// `Queue.Inline` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter. Uses ring buffer semantics for O(1) operations.
    ///
    /// - Note: This type is declared inside `Queue` (not in an extension) due to a
    ///   Swift compiler bug where nested types with value generic parameters declared
    ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
    public struct Inline<let capacity: Int>: ~Copyable {
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        static var _maxStride: Int { 64 }

        /// Raw byte storage. Each slot is 64 bytes (8 Ints on 64-bit).
        @usableFromInline
        var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Ring buffer head index (next dequeue position).
        @usableFromInline
        var _head: Int

        /// Ring buffer tail index (next enqueue position).
        @usableFromInline
        var _tail: Int

        /// Current element count.
        @usableFromInline
        var _count: Int

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

            let stride = MemoryLayout<Element>.stride
            var index = _head
            unsafe Swift.withUnsafeBytes(of: _storage) { bytes in
                let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                for _ in 0..<count {
                    let elementPtr = unsafe (basePtr + index * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                    index = (index + 1) % capacity
                }
            }
        }

        /// Returns a mutable pointer to the element at the given index.
        @usableFromInline
        @unsafe
        mutating func _pointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafeMutablePointer(to: &_storage) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        /// Returns a read-only pointer to the element at the given index.
        @usableFromInline
        @unsafe
        func _readPointerToElement(at index: Int) -> UnsafePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafePointer(to: _storage) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        /// Returns the base pointer for element storage.
        @usableFromInline
        @unsafe
        func _basePointer() -> UnsafePointer<Element> {
            unsafe Swift.withUnsafePointer(to: _storage) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                return unsafe basePtr.assumingMemoryBound(to: Element.self)
            }
        }

        /// Returns the mutable base pointer for element storage.
        @usableFromInline
        @unsafe
        mutating func _mutableBasePointer() -> UnsafeMutablePointer<Element> {
            unsafe Swift.withUnsafeMutablePointer(to: &_storage) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                return unsafe basePtr.assumingMemoryBound(to: Element.self)
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
        var _inline: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Ring buffer head index (inline mode only).
        @usableFromInline
        var _head: Int

        /// Ring buffer tail index (inline mode only).
        @usableFromInline
        var _tail: Int

        /// Current element count (valid in both inline and heap modes).
        @usableFromInline
        var _count: Int

        /// Heap storage when spilled. Nil when using inline storage.
        @usableFromInline
        var _heap: Storage?

        /// Cached pointer to heap elements. Only valid when _heap is non-nil.
        @usableFromInline
        var _heapPtr: UnsafeMutablePointer<Element>?

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
                heap.header = (head: heap.header.head, tail: heap.header.tail, count: count)
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

        // MARK: - Internal Helpers

        /// Returns a mutable pointer to the inline element at the given index.
        @usableFromInline
        @unsafe
        mutating func _inlinePointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafeMutablePointer(to: &_inline) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        /// Returns a read-only pointer to the inline element at the given index.
        @usableFromInline
        @unsafe
        func _inlineReadPointerToElement(at index: Int) -> UnsafePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafePointer(to: _inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        /// Spills inline storage to heap, linearizing the ring buffer.
        @usableFromInline
        mutating func _spillToHeap(minimumCapacity: Int) {
            precondition(_heap == nil, "Already spilled")

            // Create heap storage with growth factor
            let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
            let newStorage = Storage.create(minimumCapacity: newCapacity)
            newStorage.header = (head: 0, tail: _count, count: _count)

            // Move elements from inline (ring buffer) to heap (linear)
            let stride = MemoryLayout<Element>.stride
            var srcIndex = _head
            _ = unsafe Swift.withUnsafeBytes(of: _inline) { bytes in
                unsafe newStorage.withUnsafeMutablePointerToElements { heapPtr in
                    let inlineBase = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for dstIndex in 0..<_count {
                        let inlineElement = unsafe (inlineBase + srcIndex * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe (heapPtr + dstIndex).initialize(to: inlineElement.move())
                        srcIndex = (srcIndex + 1) % inlineCapacity
                    }
                }
            }

            _heap = newStorage
            unsafe (_heapPtr = newStorage._elementsPointer)
        }
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
        var _storage: Storage  // Uses unified nested storage class

        /// Cached pointer to element storage. Stored in struct to enable property-based Span access.
        /// CRITICAL: Must be updated whenever _storage is replaced (CoW copy).
        @usableFromInline
        var _cachedPtr: UnsafeMutablePointer<Element>

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

    /// Creates an empty queue.
    ///
    /// No allocation occurs until the first enqueue.
    @inlinable
    public init() {
        self._storage = Storage.create()
        unsafe (self._cachedPtr = _storage._elementsPointer)
    }

    /// Creates a queue initialized with elements from a sequence.
    ///
    /// - Parameter elements: The elements to enqueue.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public init(_ elements: some Sequence<Element>) {
        self.init()
        for element in elements {
            enqueue(element)
        }
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

// Note: Queue.Small and Queue.Inline are UNCONDITIONALLY ~Copyable due to deinit requirement

/// `Queue.Bounded` conforms to `Sequence` when `Element` is `Copyable`.
///
/// - Note: This conformance must be in the same file as the type declaration
///   due to a Swift compiler bug where protocol conformances for nested types
///   in separate files cause `~Copyable` constraint propagation to fail.
extension Queue.Bounded: Sequence where Element: Copyable {

    /// An iterator over the elements of a bounded queue.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _storage: Queue<Element>.Storage

        @usableFromInline
        let _capacity: Int

        @usableFromInline
        var _current: Int

        @usableFromInline
        var _remaining: Int

        @usableFromInline
        init(storage: Queue<Element>.Storage, capacity: Int) {
            self._storage = storage
            self._capacity = capacity
            self._current = storage.header.head
            self._remaining = storage.header.count
        }

        /// Advances to the next element and returns it, or nil if no next element exists.
        @inlinable
        public mutating func next() -> Element? {
            guard _remaining > 0 else { return nil }
            let element = _storage._readElement(at: _current)
            _current = (_current + 1) % _capacity
            _remaining -= 1
            return element
        }
    }

    /// Returns an iterator over the elements of the queue.
    ///
    /// Elements are yielded from front (oldest) to back (newest).
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(storage: _storage, capacity: _storage.capacity)
    }
}

// MARK: - Properties

extension Queue where Element: ~Copyable {
    /// The current number of elements in the queue.
    @inlinable
    public var count: Int { _storage.header.count }

    /// Whether the queue is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header.count == 0 }

    /// The current capacity of the queue.
    @inlinable
    public var capacity: Int { _storage.capacity }
}

// MARK: - Capacity Management

extension Queue where Element: ~Copyable {
    /// Ensures the queue has capacity for at least the specified number of elements.
    @usableFromInline
    mutating func ensureCapacity(_ minimumCapacity: Int) {
        guard _storage.capacity < minimumCapacity else { return }

        // Growth factor 2.0, minimum capacity 4
        let newCapacity = Swift.max(minimumCapacity, _storage.capacity * 2, 4)
        let newStorage = Queue<Element>.Storage.create(minimumCapacity: newCapacity)
        let currentCount = _storage.header.count

        _storage._moveAllElements(to: newStorage)
        newStorage.header = (head: 0, tail: currentCount, count: currentCount)
        _storage = newStorage
        unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL: Update cached pointer
    }

    /// Reserves capacity for at least the specified number of elements.
    ///
    /// Use this method to avoid multiple reallocations when adding a known
    /// number of elements.
    ///
    /// - Parameter minimumCapacity: The minimum total capacity to reserve.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        ensureCapacity(minimumCapacity)
    }
}

// MARK: - Core Operations (Base - for ~Copyable elements)

extension Queue where Element: ~Copyable {
    /// Enqueues an element at the back of the queue.
    ///
    /// - Parameter element: The element to enqueue.
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func enqueue(_ element: consuming Element) {
        ensureCapacity(_storage.header.count + 1)
        let tail = _storage.header.tail
        _storage._initializeElement(at: tail, to: element)
        _storage.header.tail = (tail + 1) % _storage.capacity
        _storage.header.count += 1
    }

    /// Dequeues and returns the front element, or nil if empty.
    ///
    /// - Returns: The front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func dequeue() -> Element? {
        guard _storage.header.count > 0 else {
            return nil
        }
        let head = _storage.header.head
        let element = _storage._moveElement(at: head)
        _storage.header.head = (head + 1) % _storage.capacity
        _storage.header.count -= 1
        return element
    }

    /// Removes all elements from the queue.
    ///
    /// - Parameter keepingCapacity: If `true`, the queue keeps its current capacity.
    ///   If `false`, the storage is released. Default is `true`.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        _storage._deinitializeAllElements()
        _storage.header = (head: 0, tail: 0, count: 0)

        if !keepingCapacity {
            _storage = Storage.create()
            unsafe (_cachedPtr = _storage._elementsPointer)  // Update cached pointer
        }
    }
}

// MARK: - Copy-on-Write (Copyable elements only)

extension Queue where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
            unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL: Update cached pointer
        }
    }

    /// Enqueues an element at the back of the queue (CoW-aware).
    ///
    /// - Parameter element: The element to enqueue.
    /// - Complexity: O(1) amortized, O(n) if copy triggered
    @inlinable
    public mutating func enqueue(_ element: Element) {
        makeUnique()
        ensureCapacity(_storage.header.count + 1)
        let tail = _storage.header.tail
        _storage._initializeElement(at: tail, to: element)
        _storage.header.tail = (tail + 1) % _storage.capacity
        _storage.header.count += 1
    }

    /// Dequeues and returns the front element, or nil if empty (CoW-aware).
    ///
    /// - Returns: The front element, or `nil` if the queue is empty.
    /// - Complexity: O(1), O(n) if copy triggered
    @inlinable
    public mutating func dequeue() -> Element? {
        makeUnique()
        guard _storage.header.count > 0 else {
            return nil
        }
        let head = _storage.header.head
        let element = _storage._moveElement(at: head)
        _storage.header.head = (head + 1) % _storage.capacity
        _storage.header.count -= 1
        return element
    }

    /// Removes all elements from the queue (CoW-aware).
    ///
    /// - Parameter keepingCapacity: If `true`, the queue keeps its current capacity.
    ///   If `false`, the storage is released. Default is `true`.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        makeUnique()
        _storage._deinitializeAllElements()
        _storage.header = (head: 0, tail: 0, count: 0)

        if !keepingCapacity {
            _storage = Storage.create()
            unsafe (_cachedPtr = _storage._elementsPointer)  // Update cached pointer
        }
    }
}

// MARK: - Peek

extension Queue where Element: ~Copyable {
    /// Peeks at the front element without removing it.
    ///
    /// Uses a closure to support `~Copyable` elements via borrowing.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the front element.
    /// - Returns: The result of the closure, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek<R>(_ body: (borrowing Element) -> R) -> R? {
        guard _storage.header.count > 0 else {
            return nil
        }
        let head = _storage.header.head
        return unsafe _storage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + head).pointee)
        }
    }
}

extension Queue {
    /// Returns the front element without removing it, or nil if empty.
    ///
    /// This is a convenience method for `Copyable` elements. For `~Copyable`
    /// elements, use ``peek(_:)`` with a closure.
    ///
    /// - Returns: A copy of the front element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek() -> Element? {
        guard _storage.header.count > 0 else {
            return nil
        }
        return _storage._readElement(at: _storage.header.head)
    }
}

// MARK: - Span Access
//
// Note: Ring buffer queues may have non-contiguous storage (wrapping).
// Full Span access requires linearizing, which we avoid for efficiency.
// Instead, provide forEach-based iteration for ~Copyable elements.

extension Queue where Element: ~Copyable {
    /// Calls the given closure for each element in the queue.
    ///
    /// Elements are visited from front (oldest) to back (newest).
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        let count = _storage.header.count
        guard count > 0 else { return }
        let cap = _storage.capacity
        var index = _storage.header.head
        _ = unsafe _storage.withUnsafeMutablePointerToElements { elements in
            for _ in 0..<count {
                body(unsafe (elements + index).pointee)
                index = (index + 1) % cap
            }
        }
    }
}

// MARK: - Sequence (Copyable elements only)

/// `Queue` conforms to `Sequence` when `Element` is `Copyable`.
///
/// This enables `for-in` loops, `map`, `filter`, and other sequence operations.
/// For `~Copyable` elements, use ``forEach(_:)`` instead.
extension Queue: Sequence where Element: Copyable {

    /// An iterator over the elements of a queue.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _storage: Queue<Element>.Storage

        @usableFromInline
        var _current: Int

        @usableFromInline
        var _remaining: Int

        @usableFromInline
        init(storage: Queue<Element>.Storage) {
            self._storage = storage
            self._current = storage.header.head
            self._remaining = storage.header.count
        }

        /// Advances to the next element and returns it, or nil if no next element exists.
        @inlinable
        public mutating func next() -> Element? {
            guard _remaining > 0 else { return nil }
            let element = _storage._readElement(at: _current)
            _current = (_current + 1) % _storage.capacity
            _remaining -= 1
            return element
        }
    }

    /// Returns an iterator over the elements of the queue.
    ///
    /// Elements are yielded from front (oldest) to back (newest).
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(storage: _storage)
    }
}

// MARK: - Sendable

/// `Queue` is `Sendable` when its elements are `Sendable`.
extension Queue: @unchecked Sendable where Element: Sendable {}

// MARK: - Capacity Management (Additional)

extension Queue where Element: ~Copyable {
    /// Reduces capacity to match the current count, releasing unused memory.
    ///
    /// After calling this method, `capacity == count`. The ring buffer is
    /// linearized during compaction.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func compact() {
        let currentCount = _storage.header.count
        guard _storage.capacity > currentCount else { return }

        if currentCount == 0 {
            _storage = Storage.create()
            unsafe (_cachedPtr = _storage._elementsPointer)  // Update cached pointer
            return
        }

        let newStorage = Queue<Element>.Storage.create(minimumCapacity: currentCount)
        _storage._moveAllElements(to: newStorage)
        newStorage.header = (head: 0, tail: currentCount, count: currentCount)
        _storage = newStorage
        unsafe (_cachedPtr = _storage._elementsPointer)  // Update cached pointer
    }
}

// MARK: - CoW-aware Capacity Management (Copyable elements)

extension Queue where Element: Copyable {
    /// Reduces capacity to match the current count, releasing unused memory (CoW-aware).
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func compact() {
        makeUnique()
        let currentCount = _storage.header.count
        guard _storage.capacity > currentCount else { return }

        if currentCount == 0 {
            _storage = Storage.create()
            unsafe (_cachedPtr = _storage._elementsPointer)  // Update cached pointer
            return
        }

        let newStorage = Queue<Element>.Storage.create(minimumCapacity: currentCount)
        _storage._copyAllElements(to: newStorage)
        newStorage.header = (head: 0, tail: currentCount, count: currentCount)
        _storage = newStorage
        unsafe (_cachedPtr = _storage._elementsPointer)  // Update cached pointer
    }
}

// MARK: - Storage Copyable Helpers

extension Queue.Storage where Element: Copyable {

    /// Creates a copy of this storage with all elements duplicated and linearized.
    @usableFromInline
    func copy() -> Queue.Storage {
        let count = header.count
        guard count > 0 else {
            return Queue.Storage.create()
        }

        let new = Queue.Storage.create(minimumCapacity: capacity)
        new.header = (head: 0, tail: count, count: count)

        // Copy elements in ring buffer order, linearizing
        let cap = capacity
        var srcIndex = header.head
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe new.withUnsafeMutablePointerToElements { dst in
                for dstIndex in 0..<count {
                    unsafe (dst + dstIndex).initialize(to: src[srcIndex])
                    srcIndex = (srcIndex + 1) % cap
                }
            }
        }

        return new
    }

    /// Reads element at the given index.
    @usableFromInline
    func _readElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe elements[index]
        }
    }

    /// Copies all elements to new storage (linearized).
    @usableFromInline
    func _copyAllElements(to newStorage: Queue.Storage) {
        let count = header.count
        guard count > 0 else { return }
        let cap = capacity
        var srcIndex = header.head
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                for dstIndex in 0..<count {
                    unsafe (dst + dstIndex).initialize(to: src[srcIndex])
                    srcIndex = (srcIndex + 1) % cap
                }
            }
        }
    }
}
