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

// MARK: - Queue.Fixed Tests

@Suite("Queue.Fixed")
struct QueueFixedTests {

    @Test("Initialize with valid capacity")
    func initializeWithValidCapacity() {
        let queue = Queue<Int>.Fixed(capacity: 10)
        #expect(queue.capacity == 10)
        #expect(queue.count == 0)
        #expect(queue.isEmpty)
        #expect(!queue.isFull)
    }

    @Test("Initialize with zero capacity")
    func initializeWithZeroCapacity() {
        let queue = Queue<Int>.Fixed(capacity: 0)
        #expect(queue.capacity == 0)
        #expect(queue.count == 0)
        #expect(queue.isEmpty)
        #expect(queue.isFull)
    }

    @Test("Enqueue and dequeue FIFO order")
    func enqueueAndDequeueFIFO() throws {
        var queue = Queue<Int>.Fixed(capacity: 5)
        try queue.enqueue(1)
        try queue.enqueue(2)
        try queue.enqueue(3)

        #expect(queue.count == 3)
        #expect(queue.dequeue() == 1)
        #expect(queue.dequeue() == 2)
        #expect(queue.dequeue() == 3)
        #expect(queue.dequeue() == nil)
        #expect(queue.isEmpty)
    }

    @Test("Overflow throws error")
    func overflowThrows() throws {
        var queue = Queue<Int>.Fixed(capacity: 2)
        try queue.enqueue(1)
        try queue.enqueue(2)

        #expect(queue.isFull)
        #expect(throws: __QueueBoundedError.overflow) {
            try queue.enqueue(3)
        }
    }

    @Test("Peek returns front element")
    func peekReturnsFront() throws {
        var queue = Queue<Int>.Fixed(capacity: 3)
        try queue.enqueue(1)
        try queue.enqueue(2)

        #expect(queue.peek() == 1)
        #expect(queue.count == 2)  // Peek doesn't remove
    }

    @Test("Ring buffer wrap-around")
    func ringBufferWrapAround() throws {
        var queue = Queue<Int>.Fixed(capacity: 3)

        // Fill queue
        try queue.enqueue(1)
        try queue.enqueue(2)
        try queue.enqueue(3)

        // Dequeue two
        #expect(queue.dequeue() == 1)
        #expect(queue.dequeue() == 2)

        // Enqueue two more (wraps around)
        try queue.enqueue(4)
        try queue.enqueue(5)

        // Verify FIFO order
        #expect(queue.dequeue() == 3)
        #expect(queue.dequeue() == 4)
        #expect(queue.dequeue() == 5)
        #expect(queue.dequeue() == nil)
    }

    @Test("Clear empties queue")
    func clearEmptiesQueue() throws {
        var queue = Queue<Int>.Fixed(capacity: 5)
        try queue.enqueue(1)
        try queue.enqueue(2)
        try queue.enqueue(3)

        queue.clear()

        #expect(queue.isEmpty)
        #expect(queue.count == 0)
        #expect(queue.capacity == 5)  // Capacity unchanged
    }

    @Test("ForEach iterates in FIFO order")
    func forEachIteratesInFIFOOrder() throws {
        var queue = Queue<Int>.Fixed(capacity: 5)
        try queue.enqueue(1)
        try queue.enqueue(2)
        try queue.enqueue(3)

        var result: [Int] = []
        queue.forEach { result.append($0) }

        #expect(result == [1, 2, 3])
    }

    @Test("ForEach iteration (via forEach)")
    func forEachIteration() throws {
        var queue = Queue<Int>.Fixed(capacity: 5)
        try queue.enqueue(10)
        try queue.enqueue(20)
        try queue.enqueue(30)

        var result: [Int] = []
        queue.forEach { element in
            result.append(element)
        }

        #expect(result == [10, 20, 30])
    }
}

// MARK: - Queue (Unbounded) Tests

@Suite("Queue (Unbounded)")
struct QueueUnboundedTests {

    @Test("Initialize empty")
    func initializeEmpty() {
        let queue = Queue<Int>()
        #expect(queue.count == 0)
        #expect(queue.isEmpty)
    }

    @Test("Initialize from sequence")
    func initializeFromSequence() {
        let queue: Queue<Int> = [1, 2, 3]
        #expect(queue.count == 3)
    }

    @Test("Initialize with reserved capacity")
    func initializeWithReservedCapacity() {
        let queue = Queue<Int>(reservingCapacity: 100)
        #expect(queue.capacity >= 100)
        #expect(queue.count == 0)
    }

    @Test("Enqueue and dequeue FIFO order")
    func enqueueAndDequeueFIFO() {
        var queue = Queue<Int>()
        queue.enqueue(1)
        queue.enqueue(2)
        queue.enqueue(3)

        #expect(queue.count == 3)
        #expect(queue.dequeue() == 1)
        #expect(queue.dequeue() == 2)
        #expect(queue.dequeue() == 3)
        #expect(queue.dequeue() == nil)
    }

    @Test("Automatic growth")
    func automaticGrowth() {
        var queue = Queue<Int>()

        // Enqueue many elements to trigger growth
        for i in 0..<100 {
            queue.enqueue(i)
        }

        #expect(queue.count == 100)

        // Verify FIFO order
        for i in 0..<100 {
            #expect(queue.dequeue() == i)
        }
    }

    @Test("Peek returns front element")
    func peekReturnsFront() {
        var queue = Queue<Int>()
        queue.enqueue(10)
        queue.enqueue(20)

        #expect(queue.peek() == 10)
        #expect(queue.count == 2)
    }

    @Test("Clear releases storage")
    func clearReleasesStorage() {
        var queue = Queue<Int>()
        for i in 0..<50 {
            queue.enqueue(i)
        }

        let capacityBefore = queue.capacity
        queue.clear(keepingCapacity: false)

        #expect(queue.isEmpty)
        #expect(queue.capacity < capacityBefore)
    }

    @Test("Compact reduces capacity")
    func compactReducesCapacity() {
        var queue = Queue<Int>()
        for i in 0..<50 {
            queue.enqueue(i)
        }

        // Dequeue most elements
        for _ in 0..<45 {
            _ = queue.dequeue()
        }

        queue.compact()

        #expect(queue.count == 5)
        #expect(queue.capacity == 5)
    }

    @Test("Sequence iteration")
    func sequenceIteration() {
        var queue = Queue<Int>()
        queue.enqueue(1)
        queue.enqueue(2)
        queue.enqueue(3)

        var result: [Int] = []
        for element in queue {
            result.append(element)
        }

        #expect(result == [1, 2, 3])
    }

    @Test("Reserve capacity")
    func reserveCapacity() {
        var queue = Queue<Int>()
        queue.reserve(100)

        #expect(queue.capacity >= 100)
        #expect(queue.isEmpty)
    }
}

// MARK: - Move-Only Element Tests

@Suite("Move-Only Elements")
struct MoveOnlyElementTests {

    struct MoveOnlyValue: ~Copyable {
        let value: Int

        init(_ value: Int) {
            self.value = value
        }
    }

    @Test("Fixed queue with move-only elements")
    func fixedWithMoveOnly() throws {
        var queue = Queue<MoveOnlyValue>.Fixed(capacity: 5)
        try queue.enqueue(MoveOnlyValue(1))
        try queue.enqueue(MoveOnlyValue(2))

        #expect(queue.count == 2)

        if let first = queue.dequeue() {
            #expect(first.value == 1)
        } else {
            Issue.record("Expected element")
        }

        if let second = queue.dequeue() {
            #expect(second.value == 2)
        } else {
            Issue.record("Expected element")
        }
    }

    @Test("Unbounded queue with move-only elements")
    func unboundedWithMoveOnly() {
        var queue = Queue<MoveOnlyValue>()
        queue.enqueue(MoveOnlyValue(10))
        queue.enqueue(MoveOnlyValue(20))

        #expect(queue.count == 2)

        if let first = queue.dequeue() {
            #expect(first.value == 10)
        } else {
            Issue.record("Expected element")
        }
    }

    @Test("Peek with closure for move-only")
    func peekWithClosureForMoveOnly() throws {
        var queue = Queue<MoveOnlyValue>.Fixed(capacity: 5)
        try queue.enqueue(MoveOnlyValue(42))

        let result = queue.peek { $0.value }
        #expect(result == 42)
        #expect(queue.count == 1)  // Not removed
    }
}

// MARK: - Queue.Static Tests

@Suite("Queue.Static")
struct QueueStaticTests {

    @Test("Initialize empty")
    func initializeEmpty() {
        let queue = Queue<Int>.Static<8>()
        #expect(queue.count == 0)
        #expect(queue.isEmpty == true)
        #expect(queue.isFull == false)
    }

    @Test("Enqueue and dequeue FIFO order")
    func enqueueAndDequeueFIFO() throws {
        var queue = Queue<Int>.Static<8>()
        try queue.enqueue(1)
        try queue.enqueue(2)
        try queue.enqueue(3)

        #expect(queue.count == 3)
        #expect(queue.dequeue() == 1)
        #expect(queue.dequeue() == 2)
        #expect(queue.dequeue() == 3)
        #expect(queue.dequeue() == nil)
    }

    @Test("Overflow throws error")
    func overflowThrows() throws {
        var queue = Queue<Int>.Static<2>()
        try queue.enqueue(1)
        try queue.enqueue(2)

        #expect(queue.isFull == true)
        #expect(throws: __QueueStaticError.overflow) {
            try queue.enqueue(3)
        }
    }

    @Test("Ring buffer wrap-around")
    func ringBufferWrapAround() throws {
        var queue = Queue<Int>.Static<3>()

        try queue.enqueue(1)
        try queue.enqueue(2)
        try queue.enqueue(3)

        #expect(queue.dequeue() == 1)
        #expect(queue.dequeue() == 2)

        try queue.enqueue(4)
        try queue.enqueue(5)

        #expect(queue.dequeue() == 3)
        #expect(queue.dequeue() == 4)
        #expect(queue.dequeue() == 5)
    }

    @Test("Clear empties queue")
    func clearEmptiesQueue() throws {
        var queue = Queue<Int>.Static<8>()
        try queue.enqueue(1)
        try queue.enqueue(2)

        queue.clear()

        #expect(queue.isEmpty == true)
        #expect(queue.count == 0)
    }

    @Test("Peek returns front element")
    func peekReturnsFront() throws {
        var queue = Queue<Int>.Static<8>()
        try queue.enqueue(10)
        try queue.enqueue(20)

        #expect(queue.peek() == 10)
        #expect(queue.count == 2)
    }

    @Test("ForEach iterates in FIFO order")
    func forEachIteratesInFIFOOrder() throws {
        var queue = Queue<Int>.Static<8>()
        try queue.enqueue(1)
        try queue.enqueue(2)
        try queue.enqueue(3)

        var result: [Int] = []
        queue.forEach { result.append($0) }

        #expect(result == [1, 2, 3])
    }
}

// MARK: - Queue.Small Tests

@Suite("Queue.Small")
struct QueueSmallTests {

    @Test("Initialize empty")
    func initializeEmpty() {
        let queue = Queue<Int>.Small<4>()
        #expect(queue.count == 0)
        #expect(queue.isEmpty == true)
        #expect(queue.isSpilled == false)
    }

    @Test("Inline storage")
    func inlineStorage() {
        var queue = Queue<Int>.Small<4>()
        queue.enqueue(1)
        queue.enqueue(2)
        queue.enqueue(3)
        queue.enqueue(4)

        #expect(queue.count == 4)
        #expect(queue.isSpilled == false)
        #expect(queue.capacity == 4)
    }

    @Test("Spill to heap")
    func spillToHeap() {
        var queue = Queue<Int>.Small<4>()
        queue.enqueue(1)
        queue.enqueue(2)
        queue.enqueue(3)
        queue.enqueue(4)
        queue.enqueue(5)  // Triggers spill

        #expect(queue.count == 5)
        #expect(queue.isSpilled == true)
        #expect(queue.capacity > 4)
    }

    @Test("FIFO order after spill")
    func fifoOrderAfterSpill() {
        var queue = Queue<Int>.Small<2>()
        queue.enqueue(1)
        queue.enqueue(2)
        queue.enqueue(3)  // Spills
        queue.enqueue(4)

        #expect(queue.dequeue() == 1)
        #expect(queue.dequeue() == 2)
        #expect(queue.dequeue() == 3)
        #expect(queue.dequeue() == 4)
    }

    @Test("Clear removes all elements")
    func clearRemovesAll() {
        var queue = Queue<Int>.Small<4>()
        queue.enqueue(1)
        queue.enqueue(2)
        queue.enqueue(3)
        queue.enqueue(4)
        queue.enqueue(5)  // Spills

        #expect(queue.isSpilled == true)

        queue.clear()

        #expect(queue.isEmpty == true)
    }

    @Test("Clear releases heap storage")
    func clearReleasesHeapStorage() {
        var queue = Queue<Int>.Small<4>()
        for i in 0..<10 {
            queue.enqueue(i)
        }

        #expect(queue.isSpilled == true)

        queue.clear(keepingCapacity: false)

        #expect(queue.isEmpty == true)
        #expect(queue.isSpilled == false)  // Back to inline
    }

    @Test("Peek returns front element")
    func peekReturnsFront() {
        var queue = Queue<Int>.Small<4>()
        queue.enqueue(10)
        queue.enqueue(20)

        #expect(queue.peek() == 10)
        #expect(queue.count == 2)
    }

    @Test("ForEach iterates in FIFO order")
    func forEachIteratesInFIFOOrder() {
        var queue = Queue<Int>.Small<4>()
        queue.enqueue(1)
        queue.enqueue(2)
        queue.enqueue(3)

        var result: [Int] = []
        queue.forEach { result.append($0) }

        #expect(result == [1, 2, 3])
    }

    @Test("ForEach after spill")
    func forEachAfterSpill() {
        var queue = Queue<Int>.Small<2>()
        queue.enqueue(1)
        queue.enqueue(2)
        queue.enqueue(3)

        #expect(queue.isSpilled == true)

        var result: [Int] = []
        queue.forEach { result.append($0) }

        #expect(result == [1, 2, 3])
    }
}

// MARK: - Queue.Small Move-Only Tests

@Suite("Queue.Small Move-Only")
struct QueueSmallMoveOnlyTests {

    struct TrackedValue: ~Copyable {
        let value: Int
        let tracker: DeinitTracker

        init(_ value: Int, tracker: DeinitTracker) {
            self.value = value
            self.tracker = tracker
        }

        deinit {
            tracker.deinitCount += 1
        }
    }

    final class DeinitTracker: @unchecked Sendable {
        var deinitCount: Int = 0
    }

    @Test("Deinit properly cleans up inline storage")
    func deinitCleansUpInline() {
        let tracker = DeinitTracker()

        do {
            var queue = Queue<TrackedValue>.Small<4>()
            queue.enqueue(TrackedValue(1, tracker: tracker))
            queue.enqueue(TrackedValue(2, tracker: tracker))
            #expect(tracker.deinitCount == 0)
        }

        #expect(tracker.deinitCount == 2)
    }

    @Test("Deinit properly cleans up heap storage")
    func deinitCleansUpHeap() {
        let tracker = DeinitTracker()

        do {
            var queue = Queue<TrackedValue>.Small<2>()
            queue.enqueue(TrackedValue(1, tracker: tracker))
            queue.enqueue(TrackedValue(2, tracker: tracker))
            queue.enqueue(TrackedValue(3, tracker: tracker))  // Spills
            #expect(queue.isSpilled == true)
            #expect(tracker.deinitCount == 0)
        }

        #expect(tracker.deinitCount == 3)
    }

    @Test("Clear properly deinitializes")
    func clearProperlyDeinitializes() {
        let tracker = DeinitTracker()
        var queue = Queue<TrackedValue>.Small<4>()

        queue.enqueue(TrackedValue(1, tracker: tracker))
        queue.enqueue(TrackedValue(2, tracker: tracker))

        #expect(tracker.deinitCount == 0)

        queue.clear()

        #expect(tracker.deinitCount == 2)
    }
}
