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

import Queue_Primitives_Test_Support
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

    @Test
    func `Queue deinit order (simple)`() {
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

    @Test
    func `Queue.Fixed deinit order`() throws {
        let tracker = Tracker()
        do {
            var fixed = Queue<TrackedElement>.Fixed(capacity: 5)
            try fixed.enqueue(TrackedElement(1, tracker: tracker))
            try fixed.enqueue(TrackedElement(2, tracker: tracker))
            try fixed.enqueue(TrackedElement(3, tracker: tracker))
        }
        let order = tracker.deinitOrder
        #expect(order == [1, 2, 3])
    }

    @Test
    func `Queue.Fixed deinit order (with wraparound)`() throws {
        let tracker = Tracker()
        do {
            var fixed = Queue<TrackedElement>.Fixed(capacity: 4)
            try fixed.enqueue(TrackedElement(1, tracker: tracker))
            try fixed.enqueue(TrackedElement(2, tracker: tracker))
            _ = fixed.dequeue()  // Remove and deinit 1
            try fixed.enqueue(TrackedElement(3, tracker: tracker))
            try fixed.enqueue(TrackedElement(4, tracker: tracker))
            // When do block ends, elements 2, 3, 4 should be deinitialized in order
        }
        // Full order: [1, 2, 3, 4] (1 from dequeue, then 2,3,4 from deinit)
        let order = tracker.deinitOrder
        #expect(order == [1, 2, 3, 4])
    }

    @Test
    func `Empty queue deinit (no crash)`() {
        let tracker = Tracker()
        do {
            let _: Queue<TrackedElement> = Queue()
            let _: Queue<TrackedElement>.Fixed = Queue<TrackedElement>.Fixed(capacity: 5)
        }
        let order = tracker.deinitOrder
        #expect(order == [])
    }
}
