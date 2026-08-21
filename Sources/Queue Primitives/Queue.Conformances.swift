import Affine_Primitives_Standard_Library_Integration
public import Buffer_Protocol_Primitives
import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Queue_Primitive
public import Sequence_Primitives
public import Store_Protocol_Primitives

extension __Queue: Sequenceable where S: Sequenceable & ~Copyable, S.Iterator: Escapable {

    @inlinable
    public consuming func makeIterator() -> S.Iterator {
        take().makeIterator()
    }
}

extension __Queue where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol` {

    @inlinable
    public func forEach(_ body: (borrowing S.Element) -> Void) {
        var slot: Index = .zero
        let end = count.map(Ordinal.init)
        while slot < end {
            body(store[slot])
            slot = slot.successor.saturating()
        }
    }
}
