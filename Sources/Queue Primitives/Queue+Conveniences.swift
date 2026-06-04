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

internal import Index_Primitives
public import Buffer_Ring_Primitives
public import Queue_Primitive

// Note: the stdlib `Swift.Collection` / `BidirectionalCollection` / `RandomAccessCollection`
// conformances are dropped per the dictionary-ordered precedent — the deferred stdlib-interop
// axis. The institute typed-`Index` subscript API stays (Queue.Index.swift); index-based
// iteration is no longer exposed via the stdlib `Collection` family. Element iteration is via the
// institute `Iterable` + `Sequenceable` attachables (Queue+Iterable.swift / Queue+Sequenceable.swift).

// MARK: - Equatable (Copyable)

extension Queue: Equatable where Element: Equatable & Copyable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        // Consume snapshot copies through the Sequenceable scalar witness. The explicit
        // result type pins the consuming `makeIterator()` (the `Iterable` borrowing witness
        // is the other `@_implements(makeIterator())` overload).
        var li: Buffer<Storage<Element>.Heap>.Ring.Scalar = lhs.makeIterator()
        var ri: Buffer<Storage<Element>.Heap>.Ring.Scalar = rhs.makeIterator()
        while let l = li.next(), let r = ri.next() {
            if l != r { return false }
        }
        return true
    }
}

// MARK: - Hashable (Copyable)

extension Queue: Hashable where Element: Hashable & Copyable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        forEach { element in
            hasher.combine(element)
        }
    }
}

// MARK: - ExpressibleByArrayLiteral (Copyable)

extension Queue: ExpressibleByArrayLiteral where Element: Copyable {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init()
        for element in elements {
            enqueue(element)
        }
    }
}

// MARK: - CustomStringConvertible

#if !hasFeature(Embedded)
    extension Queue: CustomStringConvertible where Element: Copyable {
        public var description: String {
            var result = "Queue(["
            var first = true
            forEach { element in
                if !first { result += ", " }
                result += String(describing: element)
                first = false
            }
            result += "])"
            return result
        }
    }
#endif
