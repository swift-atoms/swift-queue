public import Index
public import Store_Protocol

extension __Queue where S: Store.`Protocol` & ~Copyable {

    public typealias Index = Index.Index<S.Element>
}
