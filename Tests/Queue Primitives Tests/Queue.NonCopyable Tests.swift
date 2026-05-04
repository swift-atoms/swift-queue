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

/// Comprehensive tests verifying ~Copyable element support across all Queue variants.
@Suite("Queue - NonCopyable Elements")
struct QueueNonCopyableTests {

    /// A ~Copyable test type with observable deinit
    struct Token: ~Copyable {
        let id: Int
        let onDeinit: @Sendable (Int) -> Void

        init(_ id: Int, onDeinit: @escaping @Sendable (Int) -> Void = { _ in }) {
            self.id = id
            self.onDeinit = onDeinit
        }

        deinit {
            onDeinit(id)
        }
    }

    @Test
    func `Queue with ~Copyable elements: enqueue/dequeue/peek`() {
        var queue = Queue<Token>()
        queue.enqueue(Token(1))
        queue.enqueue(Token(2))
        queue.enqueue(Token(3))

        let count = queue.count
        #expect(count == 3)

        // Peek via closure (borrowing)
        var peekedId: Int?
        _ = queue.peek { token in
            peekedId = token.id
        }
        #expect(peekedId == 1)

        // Dequeue
        if let token = queue.dequeue() {
            #expect(token.id == 1)
        } else {
            Issue.record("Expected to dequeue token")
        }

        let countAfter = queue.count
        #expect(countAfter == 2)
    }

    @Test
    func `Queue with ~Copyable elements: forEach iteration`() {
        var queue = Queue<Token>()
        queue.enqueue(Token(1))
        queue.enqueue(Token(2))
        queue.enqueue(Token(3))

        var ids: [Int] = []
        queue.forEach { token in
            ids.append(token.id)
        }

        #expect(ids == [1, 2, 3])
    }

    @Test
    func `Queue.Fixed with ~Copyable elements`() throws {
        var fixed = Queue<Token>.Fixed(capacity: 5)
        try fixed.enqueue(Token(10))
        try fixed.enqueue(Token(20))

        let count = fixed.count
        let capacity = fixed.capacity
        #expect(count == 2)
        #expect(capacity == 5)

        if let token = fixed.dequeue() {
            #expect(token.id == 10)
        } else {
            Issue.record("Expected to dequeue token")
        }
    }

    @Test
    func `Queue.Fixed with ~Copyable elements: forEach`() throws {
        var fixed = Queue<Token>.Fixed(capacity: 5)
        try fixed.enqueue(Token(1))
        try fixed.enqueue(Token(2))
        try fixed.enqueue(Token(3))

        var ids: [Int] = []
        fixed.forEach { token in
            ids.append(token.id)
        }

        #expect(ids == [1, 2, 3])
    }

    @Test
    func `Queue.Static with ~Copyable elements`() throws {
        var staticQueue = Queue<Token>.Static<4>()
        try staticQueue.enqueue(Token(100))
        try staticQueue.enqueue(Token(200))

        let count = staticQueue.count
        let isFull = staticQueue.isFull
        #expect(count == 2)
        #expect(!isFull)

        if let token = staticQueue.dequeue() {
            #expect(token.id == 100)
        } else {
            Issue.record("Expected to dequeue token")
        }
    }

    @Test
    func `Queue.Static with ~Copyable elements: forEach`() throws {
        var staticQueue = Queue<Token>.Static<4>()
        try staticQueue.enqueue(Token(1))
        try staticQueue.enqueue(Token(2))
        try staticQueue.enqueue(Token(3))

        var ids: [Int] = []
        staticQueue.forEach { token in
            ids.append(token.id)
        }

        #expect(ids == [1, 2, 3])
    }

    @Test
    func `Queue.Static with ~Copyable elements: ring buffer wraparound`() throws {
        var staticQueue = Queue<Token>.Static<3>()
        try staticQueue.enqueue(Token(1))
        try staticQueue.enqueue(Token(2))
        _ = staticQueue.dequeue()  // Remove 1, head moves
        try staticQueue.enqueue(Token(3))
        try staticQueue.enqueue(Token(4))  // Wraps around

        var ids: [Int] = []
        staticQueue.forEach { token in
            ids.append(token.id)
        }

        #expect(ids == [2, 3, 4])
    }

    @Test
    func `Queue.Small with ~Copyable elements (inline path)`() {
        var small = Queue<Token>.Small<4>()
        small.enqueue(Token(1))
        small.enqueue(Token(2))

        let count = small.count
        let isSpilled = small.isSpilled
        #expect(count == 2)
        #expect(!isSpilled)
    }

    @Test
    func `Queue.Small with ~Copyable elements (spill path)`() {
        var small = Queue<Token>.Small<2>()
        small.enqueue(Token(1000))
        small.enqueue(Token(2000))
        let notSpilled = !small.isSpilled
        #expect(notSpilled)

        small.enqueue(Token(3000))
        let isSpilled = small.isSpilled
        let count = small.count
        #expect(isSpilled)
        #expect(count == 3)

        if let token = small.dequeue() {
            #expect(token.id == 1000)
        } else {
            Issue.record("Expected to dequeue token")
        }
    }

    @Test
    func `Queue.Small with ~Copyable elements: forEach after spill`() {
        var small = Queue<Token>.Small<2>()
        small.enqueue(Token(1))
        small.enqueue(Token(2))
        small.enqueue(Token(3))  // Triggers spill

        var ids: [Int] = []
        small.forEach { token in
            ids.append(token.id)
        }

        #expect(ids == [1, 2, 3])
    }
}
