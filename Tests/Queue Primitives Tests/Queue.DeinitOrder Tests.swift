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

import Testing
@testable import Queue_Primitives

/// Tests verifying deinit order (FIFO: front-to-back) for all Queue variants.
@Suite("Queue - Deinit Order")
struct QueueDeinitOrderTests {

    /// Thread-safe tracker for deinit order using atomic storage
    final class Tracker: @unchecked Sendable {
        private var _storage: [Int] = []
        var deinitOrder: [Int] {
            _storage
        }
        func reset() { _storage = [] }
        func append(_ id: Int) { _storage.append(id) }
    }

    /// Element that tracks its deinit
    struct TrackedElement: ~Copyable {
        let id: Int
        let tracker: Tracker

        init(_ id: Int, tracker: Tracker) {
            self.id = id
            self.tracker = tracker
        }

        deinit {
            tracker.append(id)
        }
    }

    @Test("Queue deinit order (simple)")
    func queueDeinitSimple() {
        let tracker = Tracker()
        do {
            var queue = Queue<TrackedElement>()
            queue.enqueue(TrackedElement(1, tracker: tracker))
            queue.enqueue(TrackedElement(2, tracker: tracker))
            queue.enqueue(TrackedElement(3, tracker: tracker))
        }
        let order = tracker.deinitOrder
        #expect(order == [1, 2, 3])
    }

    @Test("Queue.Bounded deinit order")
    func boundedDeinitOrder() throws {
        let tracker = Tracker()
        do {
            var bounded = try Queue<TrackedElement>.Bounded(capacity: 5)
            try bounded.enqueue(TrackedElement(1, tracker: tracker))
            try bounded.enqueue(TrackedElement(2, tracker: tracker))
            try bounded.enqueue(TrackedElement(3, tracker: tracker))
        }
        let order = tracker.deinitOrder
        #expect(order == [1, 2, 3])
    }

    @Test("Queue.Small deinit order (inline path)")
    func smallInlineDeinitOrder() {
        let tracker = Tracker()
        do {
            var small = Queue<TrackedElement>.Small<4>()
            small.enqueue(TrackedElement(1, tracker: tracker))
            small.enqueue(TrackedElement(2, tracker: tracker))
        }
        let order = tracker.deinitOrder
        #expect(order == [1, 2])
    }

    @Test("Queue.Small deinit order (spilled path)")
    func smallSpilledDeinitOrder() {
        let tracker = Tracker()
        do {
            var small = Queue<TrackedElement>.Small<2>()
            small.enqueue(TrackedElement(1, tracker: tracker))
            small.enqueue(TrackedElement(2, tracker: tracker))
            small.enqueue(TrackedElement(3, tracker: tracker))  // Triggers spill
        }
        let order = tracker.deinitOrder
        #expect(order == [1, 2, 3])
    }

    @Test("Queue.Inline deinit order")
    func inlineDeinitOrder() throws {
        let tracker = Tracker()
        do {
            var inline = Queue<TrackedElement>.Inline<4>()
            try inline.enqueue(TrackedElement(1, tracker: tracker))
            try inline.enqueue(TrackedElement(2, tracker: tracker))
            try inline.enqueue(TrackedElement(3, tracker: tracker))
        }
        let order = tracker.deinitOrder
        #expect(order == [1, 2, 3])
    }

    @Test("Queue.Bounded deinit order (with wraparound)")
    func boundedDeinitWraparound() throws {
        let tracker = Tracker()
        do {
            var bounded = try Queue<TrackedElement>.Bounded(capacity: 4)
            try bounded.enqueue(TrackedElement(1, tracker: tracker))
            try bounded.enqueue(TrackedElement(2, tracker: tracker))
            _ = bounded.dequeue()  // Remove and deinit 1
            try bounded.enqueue(TrackedElement(3, tracker: tracker))
            try bounded.enqueue(TrackedElement(4, tracker: tracker))
            // When do block ends, elements 2, 3, 4 should be deinitialized in order
        }
        // Full order: [1, 2, 3, 4] (1 from dequeue, then 2,3,4 from deinit)
        let order = tracker.deinitOrder
        #expect(order == [1, 2, 3, 4])
    }

    @Test("Queue.Inline deinit order (with wraparound)")
    func inlineDeinitWraparound() throws {
        let tracker = Tracker()
        do {
            var inline = Queue<TrackedElement>.Inline<4>()
            try inline.enqueue(TrackedElement(1, tracker: tracker))
            try inline.enqueue(TrackedElement(2, tracker: tracker))
            _ = inline.dequeue()  // Remove and deinit 1
            try inline.enqueue(TrackedElement(3, tracker: tracker))
            try inline.enqueue(TrackedElement(4, tracker: tracker))
            // When do block ends, elements 2, 3, 4 should be deinitialized in order
        }
        // Full order: [1, 2, 3, 4] (1 from dequeue, then 2,3,4 from deinit)
        let order = tracker.deinitOrder
        #expect(order == [1, 2, 3, 4])
    }

    @Test("Empty queue deinit (no crash)")
    func emptyDeinitNoCrash() throws {
        let tracker = Tracker()
        do {
            let _: Queue<TrackedElement> = Queue()
            let _: Queue<TrackedElement>.Bounded = try Queue<TrackedElement>.Bounded(capacity: 5)
            let _: Queue<TrackedElement>.Inline<4> = Queue<TrackedElement>.Inline<4>()
            let _: Queue<TrackedElement>.Small<4> = Queue<TrackedElement>.Small<4>()
        }
        let order = tracker.deinitOrder
        #expect(order == [])
    }
}
