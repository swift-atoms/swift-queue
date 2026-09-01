public import Buffer_Primitive
public import Buffer_Ring_Primitive
public import Memory_Allocator_Primitive
public import Memory
public import Storage_Contiguous

public typealias Queue<E: ~Copyable> =
    __Queue<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring>
