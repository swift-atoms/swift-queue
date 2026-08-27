@_documentation(visibility: public)
@frozen
public struct __Queue<S: ~Copyable>: ~Copyable {

    @usableFromInline
    package var store: S

    @inlinable
    public init(store: consuming S) {
        self.store = store
    }

    @inlinable
    public consuming func take() -> S {
        store
    }
}

extension __Queue: Copyable where S: Copyable {}

extension __Queue: Sendable where S: Sendable & ~Copyable {}
