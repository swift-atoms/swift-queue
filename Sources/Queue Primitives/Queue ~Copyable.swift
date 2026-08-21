import Affine_Primitives_Standard_Library_Integration
public import Buffer_Protocol_Primitives
import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Queue_Primitive
public import Store_Protocol_Primitives

extension __Queue where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol` {

    @inlinable
    public var count: Index.Count {
        store.count
    }

    @inlinable
    public var isEmpty: Bool { store.isEmpty }

    @inlinable
    public var capacity: Index.Count { store.capacity }

    @inlinable
    public var freeCapacity: Index.Count {
        store.capacity.subtract.saturating(store.count)
    }
}

extension __Queue where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol` {

    @inlinable
    public mutating func dequeue() -> S.Element? {
        guard !isEmpty else { return nil }
        store.unshare()
        return store.move(at: .zero)
    }

    @inlinable
    public func peek<R>(_ body: (borrowing S.Element) -> R) -> R? {
        guard !isEmpty else { return nil }
        return body(store[.zero])
    }

    @inlinable
    public mutating func drain(_ body: (consuming S.Element) -> Void) {
        store.unshare()
        while !isEmpty {
            body(store.move(at: .zero))
        }
    }
}

extension __Queue where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol` {

    @inlinable
    public subscript(_ index: Index) -> S.Element {
        _read {
            precondition(index < count, "Index out of bounds")
            yield store[index]
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            store.unshare()
            yield &store[index]
        }
    }

    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing S.Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(store[index])
    }
}

extension __Queue where S: ~Copyable, S.Element: Copyable, S: Store.`Protocol` & Buffer.`Protocol` {

    @inlinable
    public func peek() -> S.Element? {
        guard !isEmpty else { return nil }
        return store[.zero]
    }

    @inlinable
    public func element(at index: Index) -> S.Element? {
        guard index < count else { return nil }
        return store[index]
    }
}

extension __Queue where S: Copyable, S: Store.`Protocol` {

    @inlinable
    public borrowing func clone() -> Self {
        var result = copy self
        result.store.unshare()
        return result
    }
}
