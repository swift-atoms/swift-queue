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

    @Test("Queue with ~Copyable elements: enqueue/dequeue/peek")
    func queueWithNonCopyable() {
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

    @Test("Queue with ~Copyable elements: forEach iteration")
    func queueForEach() {
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

    @Test("Queue.Bounded with ~Copyable elements")
    func boundedWithNonCopyable() throws {
        var bounded = try Queue<Token>.Bounded(capacity: 5)
        try bounded.enqueue(Token(10))
        try bounded.enqueue(Token(20))

        let count = bounded.count
        let capacity = bounded.capacity
        #expect(count == 2)
        #expect(capacity == 5)

        if let token = bounded.dequeue() {
            #expect(token.id == 10)
        } else {
            Issue.record("Expected to dequeue token")
        }
    }

    @Test("Queue.Bounded with ~Copyable elements: forEach")
    func boundedForEach() throws {
        var bounded = try Queue<Token>.Bounded(capacity: 5)
        try bounded.enqueue(Token(1))
        try bounded.enqueue(Token(2))
        try bounded.enqueue(Token(3))

        var ids: [Int] = []
        bounded.forEach { token in
            ids.append(token.id)
        }

        #expect(ids == [1, 2, 3])
    }

    @Test("Queue.Static with ~Copyable elements")
    func staticWithNonCopyable() throws {
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

    @Test("Queue.Static with ~Copyable elements: forEach")
    func staticForEach() throws {
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

    @Test("Queue.Static with ~Copyable elements: ring buffer wraparound")
    func staticWraparound() throws {
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

    @Test("Queue.Small with ~Copyable elements (inline path)")
    func smallInlineWithNonCopyable() {
        var small = Queue<Token>.Small<4>()
        small.enqueue(Token(1))
        small.enqueue(Token(2))

        let count = small.count
        let isSpilled = small.isSpilled
        #expect(count == 2)
        #expect(!isSpilled)
    }

    @Test("Queue.Small with ~Copyable elements (spill path)")
    func smallSpillWithNonCopyable() {
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

    @Test("Queue.Small with ~Copyable elements: forEach after spill")
    func smallForEachAfterSpill() {
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
