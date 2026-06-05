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

/// Tests verifying Sendable conformance when Element: Sendable.
@Suite("Queue - Sendable Conformance")
struct QueueSendableTests {

    /// Compile-time check: value conforms to Sendable
    func requireSendable<T: Sendable>(_ value: T) {
        // Compile-time verification only
    }

    @Test
    func `Queue<Int> is Sendable`() {
        var queue = Queue<Int>()
        queue.enqueue(1)
        queue.enqueue(2)
        queue.enqueue(3)
        requireSendable(queue)
    }

    @Test
    func `Queue<String> is Sendable`() {
        var queue = Queue<String>()
        queue.enqueue("a")
        queue.enqueue("b")
        queue.enqueue("c")
        requireSendable(queue)
    }

    @Test
    func `Queue.Fixed<Int> is Sendable`() throws {
        var fixed = Queue<Int>.Fixed(capacity: 10)
        try fixed.enqueue(1)
        requireSendable(fixed)
    }

    @Test
    func `Async task transfer`() async {
        @Sendable
        func processInBackground(_ queue: Queue<Int>) async -> Int {
            var sum = 0
            queue.forEach { element in
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
