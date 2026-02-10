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

public import Queue_Primitives_Core
public import Index_Primitives

// MARK: - Collection (Copyable elements only)

extension Queue: Swift.Collection where Element: Copyable {
    // Index typealias is defined in Queue.Index.swift as Index_Primitives.Index<Element>
    // Subscript is defined in Queue.Index.swift with typed Index

    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { count.map(Ordinal.init) }

    @inlinable
    public func index(after i: Index) -> Index {
        var next = i
        next += .one
        return next
    }
}

// MARK: - BidirectionalCollection

extension Queue: BidirectionalCollection where Element: Copyable {
    @inlinable
    public func index(before i: Index) -> Index {
        precondition(i > startIndex, "Cannot decrement startIndex")
        return try! i.predecessor.exact()
    }
}

// MARK: - RandomAccessCollection

extension Queue: RandomAccessCollection where Element: Copyable {
    @inlinable
    public func distance(from start: Index, to end: Index) -> Int {
        // Stdlib boundary: Collection protocol requires Int
        Int(bitPattern: end.rawValue.rawValue) - Int(bitPattern: start.rawValue.rawValue)
    }

    @inlinable
    public func index(_ i: Index, offsetBy distance: Int) -> Index {
        // Stdlib boundary: Collection protocol requires Int
        let raw = Int(bitPattern: i.rawValue.rawValue) + distance
        return Index(__unchecked: (), Ordinal(UInt(bitPattern: raw)))
    }

    @inlinable
    public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        // Stdlib boundary: Collection protocol requires Int
        let raw = Int(bitPattern: i.rawValue.rawValue) + distance
        let limitRaw = Int(bitPattern: limit.rawValue.rawValue)
        if distance >= 0 {
            guard raw <= limitRaw else { return nil }
        } else {
            guard raw >= limitRaw else { return nil }
        }
        return Index(__unchecked: (), Ordinal(UInt(bitPattern: raw)))
    }
}

// MARK: - Equatable (Copyable)

extension Queue: Equatable where Element: Equatable & Copyable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var li = lhs.makeIterator()
        var ri = rhs.makeIterator()
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
