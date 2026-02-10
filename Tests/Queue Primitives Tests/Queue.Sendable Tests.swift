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

/// Tests verifying Sendable conformance when Element: Sendable.
@Suite("Queue - Sendable Conformance")
struct QueueSendableTests {

    /// Compile-time check: value conforms to Sendable
    func requireSendable<T: Sendable>(_ value: T) {
        // Compile-time verification only
    }

    /// Compile-time check: ~Copyable value conforms to Sendable
    func requireSendableNC<T: Sendable & ~Copyable>(_ value: borrowing T) {
        // Compile-time verification only
    }

    @Test("Queue<Int> is Sendable")
    func queueIntIsSendable() {
        var queue = Queue<Int>()
        queue.enqueue(1)
        queue.enqueue(2)
        queue.enqueue(3)
        requireSendable(queue)
    }

    @Test("Queue<String> is Sendable")
    func queueStringIsSendable() {
        var queue = Queue<String>()
        queue.enqueue("a")
        queue.enqueue("b")
        queue.enqueue("c")
        requireSendable(queue)
    }

    @Test("Queue.Fixed<Int> is Sendable")
    func fixedIntIsSendable() throws {
        var fixed = Queue<Int>.Fixed(capacity: 10)
        try fixed.enqueue(1)
        requireSendable(fixed)
    }

    @Test("Queue.Static<Int> is Sendable")
    func staticIntIsSendable() throws {
        var staticQueue = Queue<Int>.Static<4>()
        try staticQueue.enqueue(1)
        requireSendableNC(staticQueue)
    }

    @Test("Queue.Small<Int> is Sendable")
    func smallIntIsSendable() {
        var small = Queue<Int>.Small<4>()
        small.enqueue(1)
        requireSendableNC(small)
    }

    @Test("Async task transfer")
    func asyncTaskTransfer() async {
        @Sendable
        func processInBackground(_ queue: Queue<Int>) async -> Int {
            var sum = 0
            for element in queue {
                sum += element
            }
            return sum
        }

        var queue = Queue<Int>()
        queue.enqueue(1)
        queue.enqueue(2)
        queue.enqueue(3)
        queue.enqueue(4)
        queue.enqueue(5)

        let task = Task {
            await processInBackground(queue)
        }

        let result = await task.value
        #expect(result == 15)
    }
}
