public import Queue_Primitive

extension __Queue: Equatable where S: Equatable {

    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.store == rhs.store
    }
}
