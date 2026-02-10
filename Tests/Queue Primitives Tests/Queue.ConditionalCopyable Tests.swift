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

/// Tests verifying conditional Copyable conformance.
/// - Queue<Copyable> is Copyable
/// - Queue<~Copyable> is ~Copyable
/// - Queue.Static and Queue.Small are unconditionally ~Copyable
@Suite("Queue - Conditional Copyable")
struct QueueConditionalCopyableTests {

    struct MoveOnly: ~Copyable {
        let id: Int
    }

    @Test("Queue<Int> is Copyable")
    func queueIntIsCopyable() {
        var original = Queue<Int>()
        original.enqueue(1)
        original.enqueue(2)
        original.enqueue(3)
        let copy = original  // Copy, not move

        let origCount = original.count
        let copyCount = copy.count
        #expect(origCount == 3)
        #expect(copyCount == 3)
    }

    @Test("Queue.Fixed<Int> is Copyable")
    func fixedIntIsCopyable() throws {
        var original = Queue<Int>.Fixed(capacity: 10)
        try original.enqueue(1)
        try original.enqueue(2)

        let copy = original  // Copy, not move

        let origCount = original.count
        let copyCount = copy.count
        let origCap = original.capacity
        let copyCap = copy.capacity
        #expect(origCount == 2)
        #expect(copyCount == 2)
        #expect(origCap == copyCap)
    }

    @Test("Queue<MoveOnly> is ~Copyable")
    func queueMoveOnlyIsNotCopyable() {
        var queue = Queue<MoveOnly>()
        queue.enqueue(MoveOnly(id: 1))

        // Can only move, not copy
        let moved = consume queue
        let count = moved.count
        #expect(count == 1)
    }

    @Test("Queue.Static<Int> is unconditionally ~Copyable")
    func staticIsUnconditionallyNonCopyable() throws {
        var staticQueue = Queue<Int>.Static<4>()
        try staticQueue.enqueue(1)
        try staticQueue.enqueue(2)

        // Even with Copyable Int, Static requires consume
        let moved = consume staticQueue
        let count = moved.count
        #expect(count == 2)
    }

    @Test("Queue.Small<Int> is unconditionally ~Copyable")
    func smallIsUnconditionallyNonCopyable() {
        var small = Queue<Int>.Small<4>()
        small.enqueue(1)
        small.enqueue(2)

        // Even with Copyable Int, Small requires consume
        let moved = consume small
        let count = moved.count
        #expect(count == 2)
    }
}
