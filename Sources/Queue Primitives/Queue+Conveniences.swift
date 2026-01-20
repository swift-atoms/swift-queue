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

extension Queue: Collection where Element: Copyable {
    public typealias Index = Int

    @inlinable
    public var startIndex: Index { 0 }

    @inlinable
    public var endIndex: Index { count }

    @inlinable
    public func index(after i: Index) -> Index {
        i + 1
    }

    /// Accesses the element at the specified logical index.
    ///
    /// Index 0 is the front of the queue (oldest element).
    @inlinable
    public subscript(index: Int) -> Element {
        get {
            precondition(index >= 0 && index < count, "Index out of bounds")
            let physicalIndex = (_storage.header.head + index) % _storage.capacity
            return _storage._readElement(at: physicalIndex)
        }
        set {
            precondition(index >= 0 && index < count, "Index out of bounds")
            makeUnique()
            let physicalIndex = (_storage.header.head + index) % _storage.capacity
            unsafe _storage.withUnsafeMutablePointerToElements { elements in
                unsafe (elements[physicalIndex] = newValue)
            }
        }
    }
}

// MARK: - BidirectionalCollection

extension Queue: BidirectionalCollection where Element: Copyable {
    @inlinable
    public func index(before i: Index) -> Index {
        i - 1
    }
}

// MARK: - RandomAccessCollection

extension Queue: RandomAccessCollection where Element: Copyable {
    @inlinable
    public func distance(from start: Index, to end: Index) -> Int {
        end - start
    }

    @inlinable
    public func index(_ i: Index, offsetBy distance: Int) -> Index {
        i + distance
    }

    @inlinable
    public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        let result = i + distance
        if distance >= 0 {
            return result <= limit ? result : nil
        } else {
            return result >= limit ? result : nil
        }
    }
}

// MARK: - Equatable (Copyable)

extension Queue: Equatable where Element: Equatable & Copyable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for i in 0..<lhs.count {
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
        for i in 0..<count {
            hasher.combine(self[i])
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
        for i in 0..<count {
            if !first { result += ", " }
            result += String(describing: self[i])
            first = false
        }
        result += "])"
        return result
    }
}
#endif
