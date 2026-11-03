# swift-queue

Use this package when elements, including `~Copyable` ones, must leave in the order they arrived: enqueue at the back, dequeue from the front, nothing else. Start from `Queue<E>` (growable, unique storage). Use `Queue<E>.Bounded` when capacity is fixed and a full queue must refuse work; use `Queue<E>.Small<n>` to keep a small queue inline before it spills to the heap; use `__Queue<Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring>>` (or its `.Ring.Bounded` counterpart) when copies of a queue must be cheap and share storage until written. Every form is a `__Queue<S>` over a different store. When elements must also enter or leave at the other end, use the sibling swift-deque instead.

## Laws

- Order is first in, first out. `dequeue`, `peek`, `drain`, `forEach` and iteration all visit elements in enqueue order, also after the ring has wrapped and after `Queue<E>.Small<n>` has spilled from inline storage to the heap.
- Indices are logical positions, not storage slots: index 0 is always the front. The subscript and `withElement(at:)` trap on an index at or past `count`; `element(at:)` returns `nil` there instead.
- Growable forms never refuse an element; they grow and keep order. Bounded forms refuse an `enqueue` only when `count` equals `capacity`; after a `dequeue` they accept again.
- `drain` empties the queue. `makeIterator` consumes the queue.
- `clear` keeps capacity unless `keepingCapacity` is `false`; on bounded forms it always keeps capacity. `reserve` leaves `capacity` at least the requested count. `compact` shrinks `capacity` to `count`, keeping the elements.
- Shared forms: a copy shares storage with its original until either is mutated. Any mutation (`enqueue`, `dequeue`, `drain`, a subscript write, `clear`, `reserve`, `compact`) detaches the mutated copy first, so the other copy never observes it. `clone` always returns a queue with storage of its own, on every form.
- On shared forms, equality and hashing compare the elements front to back; capacity does not take part.
- Every element is destroyed exactly once: a dequeued element when its new owner ends it, the rest when the queue ends, whether or not the ring has wrapped.
