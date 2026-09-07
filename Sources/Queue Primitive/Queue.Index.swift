public import Index
public import Store

extension __Queue where S: Store.`Protocol` & ~Copyable {

    public typealias Index = Index.Index<S.Element>
}
