// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Index_Primitives
import Memory_Small_Primitives
import Queue_Primitives
import Queue_Small_Primitive
import Testing

// MARK: - W3.2 `Queue<E>.Small<n>` door coverage
//
// The FIFO analogue of the ring's `Buffer.Ring.Small Tests.swift` W3.1 probe, exercised
// THROUGH the family front door `Queue<Int>.Small<64>` ([DS-028] law 1): the door is a
// constrained axis-changing alias re-pointing the ring column's leaf to `Memory.Small<n>`.
// It proves (a) the door RESOLVES from the canonical alias, (b) construction + enqueue past
// the inline budget spill inline→heap and stay FIFO, and (c) the door is reachable from a
// MOVE-ONLY element (the M1 `~Copyable` restatement on the door extension — without it the
// alias would be unreachable from `Queue<E>`'s move-only canonical column).

@Suite("Queue<E>.Small<n> door")
struct QueueSmallDoorTests {

    @Test
    func `the door resolves and is FIFO across the inline→heap spill (byte budget)`() {
        // `Memory.Small`'s n is a BYTE budget: 64 bytes ≈ 8 `Int`s inline before spilling.
        var q = Queue<Int>.Small<64>(minimumCapacity: 4)
        let empty = q.isEmpty
        #expect(empty)

        // Enqueue 16 `Int`s (128 bytes) past the 64-byte inline budget, forcing at least
        // one inline→heap spill during growth (the ring's form-2 grow path).
        for value in 1...16 {
            q.enqueue(value)
        }
        #expect(q.count == Index<Int>.Count(16))

        // Drain FIFO — order preserved across the spill boundary.
        var seen: [Int] = []
        q.drain { seen.append($0) }
        #expect(seen == Array(1...16))
        let emptyAfter = q.isEmpty
        #expect(emptyAfter)
    }

    @Test
    func `the door supports the full growable family surface (enqueue / dequeue / reserve / compact / clear / clone)`() {
        var q = Queue<Int>.Small<64>()
        q.enqueue(10)
        q.enqueue(20)
        q.enqueue(30)

        // dequeue is seam-generic (form 1) — available for every column.
        let front = q.dequeue()
        #expect(front == 10)

        // reserve / compact are allocation-generic (form 2) on the Small leaf.
        q.reserve(Index<Int>.Count(32))
        #expect(q.capacity >= Index<Int>.Count(32))
        q.compact()
        #expect(q.count == Index<Int>.Count(2))

        // clone (form 2) detaches; a mutation on the copy leaves the original intact.
        var copy = q.clone()
        copy.enqueue(40)
        #expect(q.count == Index<Int>.Count(2))
        #expect(copy.count == Index<Int>.Count(3))

        // clear (form 2) empties, keeping the inline budget.
        q.clear()
        let cleared = q.isEmpty
        #expect(cleared)
    }

    @Test
    func `the door is reachable from a MOVE-ONLY element and tears down exactly once (M1 restatement)`() {
        // Compile-probe: `Queue<SmallItem>.Small<64>` typechecks ONLY if the door
        // extension restates `where S: ~Copyable` (M1) — the canonical `Queue<SmallItem>`
        // column is move-only, so a bare `where S: Store.Direct` would re-impose Copyable
        // and make `.Small` unreachable here.
        SmallItemProbe.reset()
        do {
            var q = Queue<SmallItem>.Small<64>(minimumCapacity: 2)
            q.enqueue(SmallItem(1))
            q.enqueue(SmallItem(2))
            q.enqueue(SmallItem(3))  // grows on the Small leaf (still inline: 3×8 < 64)
            #expect(q.count == Index<SmallItem>.Count(3))

            if let first = q.dequeue() {
                #expect(first.id == 1)  // FIFO front; `first` destroyed at scope end
            } else {
                Issue.record("expected the front element")
            }
        }
        // Every constructed element torn down exactly once (the dequeued one + the two
        // drained at teardown).
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
