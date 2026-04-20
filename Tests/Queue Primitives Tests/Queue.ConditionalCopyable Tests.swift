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

    @Test
    func `Queue<Int> is Copyable`() {
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

    @Test
    func `Queue.Fixed<Int> is Copyable`() throws {
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

    @Test
    func `Queue<MoveOnly> is ~Copyable`() {
        var queue = Queue<MoveOnly>()
        queue.enqueue(MoveOnly(id: 1))

        // Can only move, not copy
        let moved = consume queue
        let count = moved.count
        #expect(count == 1)
    }

    @Test
    func `Queue.Static<Int> is unconditionally ~Copyable`() throws {
        var staticQueue = Queue<Int>.Static<4>()
        try staticQueue.enqueue(1)
        try staticQueue.enqueue(2)

        // Even with Copyable Int, Static requires consume
        let moved = consume staticQueue
        let count = moved.count
        #expect(count == 2)
    }

    @Test
    func `Queue.Small<Int> is unconditionally ~Copyable`() {
        var small = Queue<Int>.Small<4>()
        small.enqueue(1)
        small.enqueue(2)

        // Even with Copyable Int, Small requires consume
        let moved = consume small
        let count = moved.count
        #expect(count == 2)
    }
}
