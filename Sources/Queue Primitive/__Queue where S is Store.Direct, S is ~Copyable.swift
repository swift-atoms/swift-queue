public import Store

extension __Queue where S: Store.Direct, S: ~Copyable {

    public typealias Bounded = __Queue<S.Bounded>
}
