public import Buffer
public import Buffer_Ring_Bounded_Primitive
public import Buffer_Ring_Primitive
public import Index
public import Memory_Allocator_Primitive
public import Memory_Allocator_Protocol
public import Memory
public import Ownership_Shared_Primitive
public import Queue_Primitive
public import Storage

extension __Queue where S: ~Copyable {

    @inlinable
    public mutating func enqueue<E: ~Copyable, Resource: Memory.Growable & ~Copyable>(
        _ element: consuming E
    )
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Ring {
        store.pushBack(element)
    }

    @inlinable
    public mutating func enqueue<E: ~Copyable>(_ element: consuming E)
    where
        S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring>
    {
        store.withUnique(consuming: element) { ring, element in
            ring.pushBack(element)
        }
    }

    @inlinable
    public mutating func enqueue<E: ~Copyable>(_ element: consuming E) throws(Error)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded {
        guard store.push.back(element) == nil else {
            throw .full
        }
    }

    @inlinable
    public mutating func enqueue<E: ~Copyable>(_ element: consuming E) throws(Error)
    where
        S == Ownership.Shared<
            E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded
        >
    {
        let rejected = store.withUnique(consuming: element) { ring, element in
            ring.push.back(element)
        }
        guard rejected == nil else {
            throw .full
        }
    }
}

extension __Queue where S: ~Copyable {

    @inlinable
    public mutating func clear<E: ~Copyable, Resource: Memory.Growable & ~Copyable>(
        keepingCapacity: Bool = true
    )
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Ring {
        store.removeAll()
        if !keepingCapacity {
            store = S(minimumCapacity: .zero)
        }
    }

    @inlinable
    public mutating func clear<E: ~Copyable>()
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded {
        store.remove.all()
    }

    @inlinable
    public mutating func clear<E>(keepingCapacity: Bool = true)
    where
        S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring>
    {
        let capacity: Index.Index<E>.Count = keepingCapacity ? store.capacity : .zero
        self.store = Ownership.Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring(
                minimumCapacity: capacity
            )
        )
    }

    @inlinable
    public mutating func clear<E>()
    where
        S == Ownership.Shared<
            E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded
        >
    {
        self.store = Ownership.Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded(
                minimumCapacity: store.capacity
            )
        )
    }
}

extension __Queue where S: ~Copyable {

    @inlinable
    public mutating func reserve<E: ~Copyable, Resource: Memory.Growable & ~Copyable>(
        _ minimumCapacity: Index.Index<E>.Count
    )
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Ring {
        store.reserveCapacity(minimumCapacity)
    }

    @inlinable
    public mutating func reserve<E: ~Copyable>(_ minimumCapacity: Index.Index<E>.Count)
    where
        S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring>
    {
        store.withUnique { ring in
            ring.reserveCapacity(minimumCapacity)
        }
    }

    @inlinable
    public mutating func compact<E: ~Copyable, Resource: Memory.Growable & ~Copyable>()
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Ring {
        store.compact()
    }

    @inlinable
    public mutating func compact<E: ~Copyable>()
    where
        S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring>
    {
        store.withUnique { ring in
            ring.compact()
        }
    }
}

extension __Queue where S: ~Copyable {

    @inlinable
    public func clone<E, Resource: Memory.Growable & ~Copyable>() -> Self
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Ring {
        Self(store: store.clone())
    }

    @inlinable
    public func clone<E>() -> Self
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded {
        Self(store: store.clone())
    }
}
