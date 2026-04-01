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
import Queue_Primitives_Test_Support
import Buffer_Primitives

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

    @Test("Queue.Fixed deinit order")
    func fixedDeinitOrder() throws {
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

    @Test("Queue.Static deinit order")
    func staticDeinitOrder() throws {
        let tracker = Tracker()
        do {
            var staticQueue = Queue<TrackedElement>.Static<4>()
            try staticQueue.enqueue(TrackedElement(1, tracker: tracker))
            try staticQueue.enqueue(TrackedElement(2, tracker: tracker))
            try staticQueue.enqueue(TrackedElement(3, tracker: tracker))
        }
        let order = tracker.deinitOrder
        #expect(order == [1, 2, 3])
    }

    @Test("Queue.Fixed deinit order (with wraparound)")
    func fixedDeinitWraparound() throws {
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

    @Test("Queue.Static deinit order (with wraparound)")
    func staticDeinitWraparound() throws {
        let tracker = Tracker()
        do {
            var staticQueue = Queue<TrackedElement>.Static<4>()
            try staticQueue.enqueue(TrackedElement(1, tracker: tracker))
            try staticQueue.enqueue(TrackedElement(2, tracker: tracker))
            _ = staticQueue.dequeue()  // Remove and deinit 1
            try staticQueue.enqueue(TrackedElement(3, tracker: tracker))
            try staticQueue.enqueue(TrackedElement(4, tracker: tracker))
            // When do block ends, elements 2, 3, 4 should be deinitialized in order
        }
        // Full order: [1, 2, 3, 4] (1 from dequeue, then 2,3,4 from deinit)
        let order = tracker.deinitOrder
        #expect(order == [1, 2, 3, 4])
    }

    /// Copyable element that tracks its deinit via reference counting.
    /// Used for Queue.DoubleEnded.Static which only has Copyable API.
    final class TrackedBox {
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

    @Test("Queue.DoubleEnded.Static deinit order")
    func doubleEndedStaticDeinitOrder() throws {
        let tracker = Tracker()
        do {
            var deque = Queue<TrackedBox>.DoubleEnded.Static<4>()
            try deque.push(TrackedBox(1, tracker: tracker), to: .back)
            try deque.push(TrackedBox(2, tracker: tracker), to: .back)
            try deque.push(TrackedBox(3, tracker: tracker), to: .back)
        }
        let order = tracker.deinitOrder
        #expect(order == [1, 2, 3])
    }

    @Test("Queue.DoubleEnded.Static deinit order (with wraparound)")
    func doubleEndedStaticDeinitWraparound() throws {
        let tracker = Tracker()
        do {
            var deque = Queue<TrackedBox>.DoubleEnded.Static<4>()
            try deque.push(TrackedBox(1, tracker: tracker), to: .back)
            try deque.push(TrackedBox(2, tracker: tracker), to: .back)
            _ = deque.pop(from: .front)  // Remove and deinit 1
            try deque.push(TrackedBox(3, tracker: tracker), to: .back)
            try deque.push(TrackedBox(4, tracker: tracker), to: .back)
        }
        let order = tracker.deinitOrder
        #expect(order == [1, 2, 3, 4])
    }

    // MARK: - Storage.Inline Deinit Regression

    /// Wrapper with empty deinit — tests that Storage.Inline's deinit fires
    /// through the explicit-deinit → member-destruction chain.
    private struct _EmptyDeinitWrapper<Element: ~Copyable, let capacity: Int>: ~Copyable {
        var _buffer: Buffer<Element>.Ring.Inline<capacity>
        init() { self._buffer = Buffer<Element>.Ring.Inline<capacity>() }
        deinit {}
    }

    /// Wrapper with NO deinit at all — tests that Storage.Inline's deinit fires
    /// through pure implicit member destruction. This is the exact shape
    /// Queue.Static would have after removing _deinitWorkaround and deinit.
    private struct _NoDeinitWrapper<Element: ~Copyable, let capacity: Int>: ~Copyable {
        var _buffer: Buffer<Element>.Ring.Inline<capacity>
        init() { self._buffer = Buffer<Element>.Ring.Inline<capacity>() }
    }

    @Test("Storage.Inline deinit — wrapper with empty deinit")
    func storageInlineDeinitEmptyDeinit() {
        let tracker = Tracker()
        do {
            var wrapper = _EmptyDeinitWrapper<TrackedElement, 4>()
            wrapper._buffer.push.back(TrackedElement(1, tracker: tracker))
            wrapper._buffer.push.back(TrackedElement(2, tracker: tracker))
            wrapper._buffer.push.back(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitOrder == [1, 2, 3])
    }

    @Test("Storage.Inline deinit — wrapper with no deinit")
    func storageInlineDeinitNoDeinit() {
        let tracker = Tracker()
        do {
            var wrapper = _NoDeinitWrapper<TrackedElement, 4>()
            wrapper._buffer.push.back(TrackedElement(1, tracker: tracker))
            wrapper._buffer.push.back(TrackedElement(2, tracker: tracker))
            wrapper._buffer.push.back(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitOrder == [1, 2, 3])
    }

    @Test("Empty queue deinit (no crash)")
    func emptyDeinitNoCrash() {
        let tracker = Tracker()
        do {
            let _: Queue<TrackedElement> = Queue()
            let _: Queue<TrackedElement>.Fixed = Queue<TrackedElement>.Fixed(capacity: 5)
            let _: Queue<TrackedElement>.Static<4> = Queue<TrackedElement>.Static<4>()
            let _: Queue<TrackedElement>.DoubleEnded.Static<4> = Queue<TrackedElement>.DoubleEnded.Static<4>()
            let _: Queue<TrackedElement>.Small<4> = Queue<TrackedElement>.Small<4>()
        }
        let order = tracker.deinitOrder
        #expect(order == [])
    }
}
