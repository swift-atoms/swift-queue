public import Buffer_Primitive
public import Buffer_Ring_Primitive
public import Memory_Allocator_Primitive
public import Memory_Small
public import Queue_Primitive
public import Storage_Contiguous
public import Store_Protocol

extension __Queue where S: ~Copyable, S: Store.Direct {

    public typealias Small<let n: Int> =
        __Queue<Buffer<Storage<Memory.Allocator<Memory.Small<n>>>.Contiguous<S.Element>>.Ring>
}
