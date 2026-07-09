import Buffer_Primitive
import Buffer_Primitives_Test_Support
import Buffer_Ring_Bounded_Primitive
import Buffer_Ring_Primitive
import Buffer_Ring_Primitives
import Index_Primitives
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Ownership_Shared_Primitive
import Queue_Primitives
import Sequence_Primitives
import Storage_Contiguous_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Testing

// The column-keyed queue suite: the four ratified ring columns through the one generic
// ADT. Per-suite destruction recorders from birth (the deterministic-gate rule).

// MARK: - The four ratified columns

private typealias HeapStorage<E: ~Copyable> =
    Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>

private typealias GrowableRing<E: ~Copyable> = Buffer<HeapStorage<E>>.Ring
private typealias BoundedRing<E: ~Copyable> = Buffer<HeapStorage<E>>.Ring.Bounded

/// The default move-only growable queue — the CANONICAL front door ([DS-028]).
private typealias MoveQueue<E: ~Copyable> = Queue<E>

/// The explicit CoW value-semantic growable queue (`Shared` column — no front
/// door yet; spelled through the carrier).
private typealias CoWQueue<E: ~Copyable> = __Queue<Ownership.Shared<E, GrowableRing<E>>>

/// The move-only fixed-capacity queue — the `.Bounded` variant front door.
private typealias FixedQueue<E: ~Copyable> = Queue<E>.Bounded

/// The CoW fixed-capacity queue (`Shared` bounded column — carrier-spelled).
private typealias CoWFixedQueue<E: ~Copyable> = __Queue<Ownership.Shared<E, BoundedRing<E>>>

// MARK: - [DS-024]: the columns are lawful from the family's own suite

@Suite
struct `Queue Column Law Tests` {

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
            makeEmpty: { Ownership.Shared(GrowableRing<Int>(minimumCapacity: Index<Int>.Count(4))) },
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

// MARK: - Construction + properties + FIFO core (all four columns)

@Suite(.serialized)
struct `Queue Core Tests` {

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
        q.enqueue(5)  // wraps physically
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
        q.enqueue(3)  // grows
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
        q[1] = 25  // gated _modify
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
    func `the bounded column carries the fixed-capacity contract (the former Queue,Fixed)`() throws {
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
        try q.enqueue(3)  // space again after a dequeue (ring wrap)
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

// MARK: - CoW value semantics (the Shared columns)

@Suite(.serialized)
struct `Queue CoW Tests` {

    @Test
    func `copies share until mutation; dequeue detaches from the sibling`() {
        var q1 = CoWQueue<Int>(minimumCapacity: 4)
        q1.enqueue(7)
        q1.enqueue(8)
        let q2 = q1  // S5: Queue is Copyable because S is
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
        q1.enqueue(2)  // withUnique(consuming:) detaches first
        let mine = q1.count
        let theirs = q2.count
        #expect(mine == Index<Int>.Count(2))
        #expect(theirs == Index<Int>.Count(1))

        var a = CoWQueue<Int>(minimumCapacity: 2)
        a.enqueue(1)
        let b = a
        a[0] = 100  // generic _modify → unshare()
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
        q1.clear()  // detach, not drain: sibling intact
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
        #expect(x == y)  // element-wise, capacity-independent
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

// MARK: - Move-only elements end-to-end + teardown

@Suite(.serialized)
struct `Queue Teardown Tests` {

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
            _ = q.dequeue()  // destroy 2 (dropped)
            q.enqueue(QueueItem(5))  // wraps: two-run ledger behind the seam
            let mid = QueueProbe.destroyedSorted
            #expect(mid == [1, 2])
            let v = q.withElement(at: 0) { $0.id }
            #expect(v == 3)
        }
        let all = QueueProbe.destroyedSorted
        #expect(all == [1, 2, 3, 4, 5])  // the oracle walked both runs at drop
    }

    @Test
    func `the boxed move-only lane tears down via the box drain`() {
        QueueProbe2.reset()
        do {
            var q = __Queue<Ownership.Shared<QueueItem2, GrowableRing<QueueItem2>>>(minimumCapacity: 2)
            q.enqueue(QueueItem2(1))
            q.enqueue(QueueItem2(2))
            let n = q.count
            #expect(n == Index<QueueItem2>.Count(2))
        }
        let all = QueueProbe2.destroyedSorted
        #expect(all == [1, 2])  // R-5: the drain destroyed the live elements
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

// MARK: - Iteration chains + Sendable smoke

@Suite
struct `Queue Iteration Tests` {

    @Test
    func `forEach walks front-to-back across the wrap; Sequenceable consumes through the column`() {
        var q = MoveQueue<Int>(minimumCapacity: 4)
        q.enqueue(1)
        q.enqueue(2)
        q.enqueue(3)
        q.enqueue(4)
        _ = q.dequeue()
        _ = q.dequeue()
        q.enqueue(5)  // wrapped
        var walked: [Int] = []
        q.forEach { walked.append($0) }
        #expect(walked == [3, 4, 5])

        var it = q.makeIterator()  // consuming, via the S chain
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
