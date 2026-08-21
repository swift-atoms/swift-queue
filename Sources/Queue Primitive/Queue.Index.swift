public import Index_Primitives
public import Store_Protocol_Primitives

extension __Queue where S: Store.`Protocol` & ~Copyable {

    public typealias Index = Index_Primitives.Index<S.Element>
}
