import Buffer_Primitive
import Buffer_Test_Support
import Buffer_Ring_Bounded_Primitive
import Buffer_Ring_Primitive
import Buffer_Ring
import Index
import Memory_Allocator_Primitive
import Memory
import Ordinal_Standard_Library_Integration
import Ownership_Shared_Primitive
import Queue
import Sequence
import Storage_Contiguous
import Tagged_Standard_Library_Integration
import Testing

private typealias HeapStorage<E: ~Copyable> =
    Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>

private typealias GrowableRing<E: ~Copyable> = Buffer<HeapStorage<E>>.Ring
private typealias BoundedRing<E: ~Copyable> = Buffer<HeapStorage<E>>.Ring.Bounded

private typealias MoveQueue<E: ~Copyable> = Queue<E>

private typealias CoWQueue<E: ~Copyable> = __Queue<Ownership.Shared<E, GrowableRing<E>>>

private typealias FixedQueue<E: ~Copyable> = Queue<E>.Bounded

private typealias CoWFixedQueue<E: ~Copyable> = __Queue<Ownership.Shared<E, BoundedRing<E>>>

@Suite
struct `Queue Column Law Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Queue Column Law Tests`.Unit {

    @Test
    func `the direct growable-ring column obeys the seam ledger laws`() {
        let violations = Seam.Ledger.violations(
            makeEmpty: { GrowableRing<Int>(minimumCapacity: Index<Int>.Count(4)) },
            element: { $0 }
        )
        #expect(violations.isEmpty, "\(violations)")
    }

    @Test
    func `the direct bounded-ring column obeys the seam ledger laws`() {
        let violations = Seam.Ledger.violations(
            makeEmpty: { BoundedRing<Int>(minimumCapacity: Index<Int>.Count(4)) },
            element: { $0 }
        )
        #expect(violations.isEmpty, "\(violations)")
    }

    @Test
    func `the shared growable-ring column obeys the seam ledger laws`() {
        let violations = Seam.Ledger.violations(
            makeEmpty: {
                Ownership.Shared(GrowableRing<Int>(minimumCapacity: Index<Int>.Count(4)))
            },
            element: { $0 }
        )
        #expect(violations.isEmpty, "\(violations)")
    }

    @Test
    func `the shared bounded-ring column obeys the seam ledger laws`() {
        let violations = Seam.Ledger.violations(
            makeEmpty: { Ownership.Shared(BoundedRing<Int>(minimumCapacity: Index<Int>.Count(4))) },
            element: { $0 }
        )
        #expect(violations.isEmpty, "\(violations)")
    }
}

@Suite(.serialized)
struct `Queue Core Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Queue Core Tests`.Unit {

    @Test
    func `direct growable queue constructs, enqueues, wraps, and dequeues FIFO`() {
        var q = MoveQueue<Int>(minimumCapacity: 4)
        let isEmpty = q.isEmpty
        #expect(isEmpty)
        q.enqueue(1)
        q.enqueue(2)
        q.enqueue(3)
        q.enqueue(4)
        let a = q.dequeue()
        let b = q.dequeue()
        #expect(a == 1)
        #expect(b == 2)
        q.enqueue(5)
        q.enqueue(6)
        let n = q.count
        #expect(n == Index<Int>.Count(4))
        var seen: [Int] = []
        q.drain { seen.append($0) }
        #expect(seen == [3, 4, 5, 6])
        let emptyAfter = q.isEmpty
        #expect(emptyAfter)
        let fromEmpty = q.dequeue()
        #expect(fromEmpty == nil)
    }

    @Test
    func `growth past the initial capacity preserves order`() {
        var q = MoveQueue<Int>(minimumCapacity: 2)
        q.enqueue(1)
        q.enqueue(2)
        q.enqueue(3)
        let capacityOK = q.capacity >= Index<Int>.Count(3)
        #expect(capacityOK)
        var seen: [Int] = []
        q.drain { seen.append($0) }
        #expect(seen == [1, 2, 3])
    }

    @Test
    func `peek borrows the front without removing; subscript reads logical positions`() {
        var q = MoveQueue<Int>(minimumCapacity: 4)
        q.enqueue(10)
        q.enqueue(20)
        let front = q.peek()
        #expect(front == 10)
        let doubled = q.peek { $0 * 2 }
        #expect(doubled == 20)
        let e1 = q[1]
        #expect(e1 == 20)
        q[1] = 25
        let opt = q.element(at: 1)
        #expect(opt == 25)
        let beyond = q.element(at: 2)
        #expect(beyond == nil)
        let n = q.count
        #expect(n == Index<Int>.Count(2))
        let viaClosure = q.withElement(at: 0) { $0 + 1 }
        #expect(viaClosure == 11)
    }

    @Test
    func `the bounded column carries the fixed-capacity contract (the former Queue,Fixed)`() throws
    {
        var q = FixedQueue<Int>(capacity: 2)
        try q.enqueue(1)
        try q.enqueue(2)
        let isFull = q.freeCapacity == Index<Int>.Count(0)
        #expect(isFull)
        var thrown: FixedQueue<Int>.Error? = nil
        do throws(FixedQueue<Int>.Error) {
            try q.enqueue(3)
        } catch {
            thrown = error
        }
        #expect(thrown == .full)
        let a = q.dequeue()
        #expect(a == 1)
        try q.enqueue(3)
        var seen: [Int] = []
        q.drain { seen.append($0) }
        #expect(seen == [2, 3])
    }

    @Test
    func `clear empties; keepingCapacity preserves slots on the growable column`() {
        var q = MoveQueue<Int>(minimumCapacity: 4)
        q.enqueue(1)
        q.enqueue(2)
        q.clear(keepingCapacity: true)
        let isEmpty = q.isEmpty
        #expect(isEmpty)
        let kept = q.capacity >= Index<Int>.Count(4)
        #expect(kept)
        q.enqueue(7)
        let front = q.peek()
        #expect(front == 7)
    }

    @Test
    func `reserve and compact reshape the growable column`() {
        var q = MoveQueue<Int>(minimumCapacity: 1)
        q.enqueue(1)
        q.reserve(Index<Int>.Count(8))
        let grown = q.capacity >= Index<Int>.Count(8)
        #expect(grown)
        q.compact()
        let exact = q.capacity
        #expect(exact == Index<Int>.Count(1))
        let kept = q.peek()
        #expect(kept == 1)
    }

    @Test
    func `pinned clone detaches the direct columns`() {
        var q = MoveQueue<Int>(minimumCapacity: 2)
        q.enqueue(4)
        q.enqueue(5)
        var c = q.clone()
        c[0] = 40
        let mine = q[0]
        let theirs = c[0]
        #expect(mine == 4)
        #expect(theirs == 40)

        var f = FixedQueue<Int>(capacity: 2)
        try? f.enqueue(9)
        let fc = f.clone()
        let fcFront = fc.peek()
        #expect(fcFront == 9)
        let fcCap = fc.capacity
        #expect(fcCap == f.capacity)
    }
}

@Suite(.serialized)
struct `Queue CoW Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Queue CoW Tests`.Unit {

    @Test
    func `copies share until mutation; dequeue detaches from the sibling`() {
        var q1 = CoWQueue<Int>(minimumCapacity: 4)
        q1.enqueue(7)
        q1.enqueue(8)
        let q2 = q1
        let popped = q1.dequeue()
        #expect(popped == 7)
        let mine = q1.count
        let theirs = q2.count
        #expect(mine == Index<Int>.Count(1))
        #expect(theirs == Index<Int>.Count(2))
        let theirFront = q2.peek()
        #expect(theirFront == 7)
    }

    @Test
    func `enqueue through the box preserves siblings; the gated subscript is CoW-correct`() {
        var q1 = CoWQueue<Int>(minimumCapacity: 2)
        q1.enqueue(1)
        let q2 = q1
        q1.enqueue(2)
        let mine = q1.count
        let theirs = q2.count
        #expect(mine == Index<Int>.Count(2))
        #expect(theirs == Index<Int>.Count(1))

        var a = CoWQueue<Int>(minimumCapacity: 2)
        a.enqueue(1)
        let b = a
        a[0] = 100
        let aSees = a[0]
        let bSees = b[0]
        #expect(aSees == 100)
        #expect(bSees == 1)
    }

    @Test
    func `the CoW bounded column keeps the fixed contract and detaches on write`() throws {
        var q1 = CoWFixedQueue<Int>(capacity: 2)
        try q1.enqueue(1)
        try q1.enqueue(2)
        let q2 = q1
        var thrown = false
        do throws(CoWFixedQueue<Int>.Error) {
            try q1.enqueue(3)
        } catch {
            thrown = true
        }
        #expect(thrown)
        q1.clear()
        let mine = q1.isEmpty
        let theirs = q2.count
        #expect(mine)
        #expect(theirs == Index<Int>.Count(2))
    }

    @Test
    func `generic clone always detaches the CoW column; carriers chain through Shared`() {
        var q = CoWQueue<Int>(minimumCapacity: 4)
        q.enqueue(1)
        q.enqueue(2)
        var c = q.clone()
        c[0] = 99
        let mine = q[0]
        let theirs = c[0]
        #expect(mine == 1)
        #expect(theirs == 99)

        var x = CoWQueue<Int>(minimumCapacity: 2)
        x.enqueue(1)
        var y = CoWQueue<Int>(minimumCapacity: 8)
        y.enqueue(1)
        #expect(x == y)
        y.enqueue(2)
        #expect(x != y)
        var h1 = Hasher()
        var h2 = Hasher()
        x.hash(into: &h1)
        var x2 = x
        x2[0] = 1
        x2.hash(into: &h2)
        #expect(h1.finalize() == h2.finalize())
    }
}

@Suite(.serialized)
struct `Queue Teardown Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Queue Teardown Tests`.Integration {

    @Test
    func `move-only elements flow through and tear down exactly once (wrapped state)`() {
        QueueProbe.reset()
        do {
            var q = MoveQueue<QueueItem>(minimumCapacity: 4)
            q.enqueue(QueueItem(1))
            q.enqueue(QueueItem(2))
            q.enqueue(QueueItem(3))
            q.enqueue(QueueItem(4))
            if let first = q.dequeue() {
                let id = first.id
                #expect(id == 1)
            } else {
                Issue.record("expected the front element")
            }
            _ = q.dequeue()
            q.enqueue(QueueItem(5))
            let mid = QueueProbe.destroyedSorted
            #expect(mid == [1, 2])
            let v = q.withElement(at: 0) { $0.id }
            #expect(v == 3)
        }
        let all = QueueProbe.destroyedSorted
        #expect(all == [1, 2, 3, 4, 5])
    }

    @Test
    func `the boxed move-only lane tears down via the box drain`() {
        QueueProbe2.reset()
        do {
            var q = __Queue<Ownership.Shared<QueueItem2, GrowableRing<QueueItem2>>>(
                minimumCapacity: 2
            )
            q.enqueue(QueueItem2(1))
            q.enqueue(QueueItem2(2))
            let n = q.count
            #expect(n == Index<QueueItem2>.Count(2))
        }
        let all = QueueProbe2.destroyedSorted
        #expect(all == [1, 2])
    }
}

private struct QueueItem: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { QueueProbe.recordDestroy(id) }
}

private enum QueueProbe {
}

extension QueueProbe {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}

private struct QueueItem2: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { QueueProbe2.recordDestroy(id) }
}

private enum QueueProbe2 {
}

extension QueueProbe2 {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}

@Suite
struct `Queue Iteration Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Queue Iteration Tests`.Unit {

    @Test
    func `forEach walks front-to-back across the wrap; Sequenceable consumes through the column`() {
        var q = MoveQueue<Int>(minimumCapacity: 4)
        q.enqueue(1)
        q.enqueue(2)
        q.enqueue(3)
        q.enqueue(4)
        _ = q.dequeue()
        _ = q.dequeue()
        q.enqueue(5)
        var walked: [Int] = []
        q.forEach { walked.append($0) }
        #expect(walked == [3, 4, 5])

        var it = q.makeIterator()
        var seen: [Int] = []
        while let x = it.next() { seen.append(x) }
        #expect(seen == [3, 4, 5])
    }

    @Test
    func `sendable composes through the columns`() {
        let a = MoveQueue<Int>(minimumCapacity: 1)
        requireSendable(a)
        let b = CoWQueue<Int>(minimumCapacity: 1)
        requireSendable(b)
        let c = FixedQueue<Int>(capacity: 1)
        requireSendable(c)
        #expect(Bool(true))
    }
}

private func requireSendable<T: Sendable & ~Copyable>(_ value: borrowing T) {}
