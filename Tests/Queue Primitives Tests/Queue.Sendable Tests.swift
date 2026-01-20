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

    @Test("Queue.Bounded<Int> is Sendable")
    func boundedIntIsSendable() throws {
        var bounded = try Queue<Int>.Bounded(capacity: 10)
        try bounded.enqueue(1)
        requireSendable(bounded)
    }

    @Test("Queue.Inline<Int> is Sendable")
    func inlineIntIsSendable() throws {
        var inline = Queue<Int>.Inline<4>()
        try inline.enqueue(1)
        requireSendableNC(inline)
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
