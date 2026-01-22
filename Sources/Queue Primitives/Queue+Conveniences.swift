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

// MARK: - Collection (Copyable elements only)

public import Index_Primitives

extension Queue: Collection where Element: Copyable {
    // Index typealias is defined in Queue.Index.swift as Index_Primitives.Index<Element>
    // Subscript is defined in Queue.Index.swift with typed Index

    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { Index(__unchecked: (), position: count) }

    @inlinable
    public func index(after i: Index) -> Index {
        Index(__unchecked: (), position: i.position.rawValue + 1)
    }
}

// MARK: - BidirectionalCollection

extension Queue: BidirectionalCollection where Element: Copyable {
    @inlinable
    public func index(before i: Index) -> Index {
        precondition(i > startIndex, "Cannot decrement startIndex")
        return Index(__unchecked: (), position: i.position.rawValue - 1)
    }
}

// MARK: - RandomAccessCollection

extension Queue: RandomAccessCollection where Element: Copyable {
    @inlinable
    public func distance(from start: Index, to end: Index) -> Int {
        (end - start).rawValue
    }

    @inlinable
    public func index(_ i: Index, offsetBy distance: Int) -> Index {
        Index(__unchecked: (), position: i.position.rawValue + distance)
    }

    @inlinable
    public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        let newPosition = i.position.rawValue + distance
        if distance >= 0 {
            guard newPosition <= limit.position.rawValue else { return nil }
        } else {
            guard newPosition >= limit.position.rawValue else { return nil }
        }
        return Index(__unchecked: (), position: newPosition)
    }
}

// MARK: - Equatable (Copyable)

extension Queue: Equatable where Element: Equatable & Copyable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for position in 0..<lhs.count {
            let i = Index(__unchecked: (), position: position)
            if lhs[i] != rhs[i] {
                return false
            }
        }
        return true
    }
}

// MARK: - Hashable (Copyable)

extension Queue: Hashable where Element: Hashable & Copyable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for position in 0..<count {
            hasher.combine(self[Index(__unchecked: (), position: position)])
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
        for position in 0..<count {
            if !first { result += ", " }
            result += String(describing: self[Index(__unchecked: (), position: position)])
            first = false
        }
        result += "])"
        return result
    }
}
#endif
