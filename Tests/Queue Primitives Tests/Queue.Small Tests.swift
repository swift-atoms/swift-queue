import Index_Primitives
import Memory_Small_Primitives
import Queue_Primitives
import Queue_Small_Primitive
import Testing

@Suite
struct `Queue Small Door Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Queue Small Door Tests`.Integration {

    @Test
    func `the door resolves and is FIFO across the inline→heap spill (byte budget)`() {

        var q = Queue<Int>.Small<64>(minimumCapacity: 4)
        let empty = q.isEmpty
        #expect(empty)

        (1...16).forEach { q.enqueue($0) }
        #expect(q.count == Index<Int>.Count(16))

        var seen: [Int] = []
        q.drain { seen.append($0) }
        #expect(seen == Array(1...16))
        let emptyAfter = q.isEmpty
        #expect(emptyAfter)
    }

    @Test
    func
        `the door supports the full growable family surface (enqueue / dequeue / reserve / compact / clear / clone)`()
    {
        var q = Queue<Int>.Small<64>()
        q.enqueue(10)
        q.enqueue(20)
        q.enqueue(30)

        let front = q.dequeue()
        #expect(front == 10)

        q.reserve(Index<Int>.Count(32))
        #expect(q.capacity >= Index<Int>.Count(32))
        q.compact()
        #expect(q.count == Index<Int>.Count(2))

        var copy = q.clone()
        copy.enqueue(40)
        #expect(q.count == Index<Int>.Count(2))
        #expect(copy.count == Index<Int>.Count(3))

        q.clear()
        let cleared = q.isEmpty
        #expect(cleared)
    }

    @Test
    func
        `the door is reachable from a MOVE-ONLY element and tears down exactly once (M1 restatement)`()
    {

        SmallItemProbe.reset()
        do {
            var q = Queue<SmallItem>.Small<64>(minimumCapacity: 2)
            q.enqueue(SmallItem(1))
            q.enqueue(SmallItem(2))
            q.enqueue(SmallItem(3))
            #expect(q.count == Index<SmallItem>.Count(3))

            if let first = q.dequeue() {
                #expect(first.id == 1)
            } else {
                Issue.record("expected the front element")
            }
        }

        #expect(SmallItemProbe.destroyedSorted == [1, 2, 3])
    }
}

private struct SmallItem: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { SmallItemProbe.recordDestroy(id) }
}

private enum SmallItemProbe {
}

extension SmallItemProbe {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}
