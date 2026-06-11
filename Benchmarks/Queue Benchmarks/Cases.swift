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

import Queue_Primitives
import Buffer_Primitive
import Buffer_Ring_Primitive
import Buffer_Ring_Bounded_Primitive
import Storage_Contiguous_Primitives
import Memory_Heap_Primitives
import Memory_Allocator_Primitive
import Shared_Primitive
import Index_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Ordinal_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Cardinal_Primitives

extension Bench {
    /// `cycle.steady`: at steady occupancy n, one enqueue + one dequeue per
    /// pair (per-op = one ring op) — the ring's wrap path runs continuously.
    /// The `stdlib.shift` subject is `Swift.Array` used naively as a queue
    /// (`append` + `removeFirst`): its `removeFirst` is O(n), which is the
    /// inventory's point of comparison — it gets a copy-class batch target so
    /// samples stay above the floor without taking minutes.
    ///
    /// `enqueue.zero`: n enqueues from zero capacity (growth + wrap-relocation
    /// policy included), teardown inside the batch on every subject alike.
    static func queueCases() -> [Result] {
        var results: [Result] = []

        for n in sizes {
            let pairs = Swift.max(1, (elementOpsTarget / 2) / n) * n
            let ops = pairs * 2
            let shiftPairs = Swift.max(16, (copiedSlotsTarget / 2) / n)
            let shiftOps = shiftPairs * 2
            let seed = opaque(1)

            var q = MoveQueue<Int>(minimumCapacity: count(n))
            for i in 0..<n { q.enqueue(i) }

            results.append(Result(
                name: "cycle.steady", subject: "tower.direct", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var sum = 0
                    for i in 0..<pairs {
                        q.enqueue(i &+ seed)
                        sum &+= q.dequeue() ?? 0
                    }
                    sink(sum)
                }
            ))

            var c = CoWQueue<Int>(minimumCapacity: count(n))
            for i in 0..<n { c.enqueue(i) }

            results.append(Result(
                name: "cycle.steady", subject: "tower.cow", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var sum = 0
                    for i in 0..<pairs {
                        c.enqueue(i &+ seed)
                        sum &+= c.dequeue() ?? 0
                    }
                    sink(sum)
                }
            ))

            // Bounded ring at capacity n+1, occupancy n: enqueue always has a
            // free slot; the throwing surface is the column's only door, and a
            // trap here would mean the bench itself is wrong.
            var f = FixedQueue<Int>(capacity: count(n + 1))
            for i in 0..<n { try! f.enqueue(i) }

            results.append(Result(
                name: "cycle.steady", subject: "tower.bounded", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var sum = 0
                    for i in 0..<pairs {
                        try! f.enqueue(i &+ seed)
                        sum &+= f.dequeue() ?? 0
                    }
                    sink(sum)
                }
            ))

            var sa: [Int] = []
            sa.reserveCapacity(n)
            for i in 0..<n { sa.append(i) }

            results.append(Result(
                name: "cycle.steady", subject: "stdlib.shift", n: n, opsPerBatch: shiftOps,
                perOpNs: sample(opsPerBatch: shiftOps) {
                    var sum = 0
                    for i in 0..<shiftPairs {
                        sa.append(i &+ seed)
                        sum &+= sa.removeFirst()
                    }
                    sink(sum)
                }
            ))

            let reps = Swift.max(1, structureOpsTarget / n)
            let buildOps = reps * n

            results.append(Result(
                name: "enqueue.zero", subject: "tower.direct", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var b = MoveQueue<Int>(minimumCapacity: .zero)
                        for i in 0..<n { b.enqueue(i &+ seed) }
                        acc &+= b.peek() ?? 0
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "enqueue.zero", subject: "tower.cow", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var b = CoWQueue<Int>(minimumCapacity: .zero)
                        for i in 0..<n { b.enqueue(i &+ seed) }
                        acc &+= b.peek() ?? 0
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "enqueue.zero", subject: "stdlib.shift", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var b: [Int] = []
                        for i in 0..<n { b.append(i &+ seed) }
                        acc &+= b.first ?? 0
                    }
                    sink(acc)
                }
            ))
        }

        return results
    }
}
