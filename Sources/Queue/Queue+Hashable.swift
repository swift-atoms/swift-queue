public import Queue_Primitive

extension __Queue: Hashable where S: Hashable {

    @inlinable
    public func hash(into hasher: inout Hasher) {
        store.hash(into: &hasher)
    }
}
