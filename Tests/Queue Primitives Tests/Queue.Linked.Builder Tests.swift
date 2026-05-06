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

// MARK: - Test Suite Structure

@Suite("Queue.Linked.Builder")
struct QueueLinkedBuilderTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite struct NonCopyable {}
    @Suite struct StaticMethods {}
    @Suite struct FIFOSemantics {}
}

// MARK: - Move-Only Test Fixture

private struct Move: ~Copyable {
    let value: Int
    init(_ value: Int) { self.value = value }
}

// MARK: - Iteration Helpers

extension QueueLinkedBuilderTests {
    fileprivate static func collected(
        _ queue: consuming Queue<Int>.Linked
    ) -> [Int] {
        var rest = consume queue
        var result: [Int] = []
        while let elem = rest.dequeue() {
            result.append(elem)
        }
        return result
    }

    fileprivate static func collected(
        _ queue: consuming Queue<Move>.Linked
    ) -> [Int] {
        var rest = consume queue
        var result: [Int] = []
        while let elem = rest.dequeue() {
            result.append(elem.value)
        }
        return result
    }
}

// MARK: - FIFO Semantics

extension QueueLinkedBuilderTests.FIFOSemantics {

    @Test
    func `Declaration order = enqueue order = dequeue order`() {
        var queue = Queue<Int>.Linked {
            1
            2
            3
        }
        #expect(queue.dequeue() == 1)
        #expect(queue.dequeue() == 2)
        #expect(queue.dequeue() == 3)
        #expect(queue.dequeue() == nil)
    }
}

// MARK: - Unit Tests

extension QueueLinkedBuilderTests.Unit {

    @Test
    func `Single element expression`() {
        let queue = Queue<Int>.Linked { 42 }
        #expect(QueueLinkedBuilderTests.collected(queue) == [42])
    }

    @Test
    func `Multiple element expressions in FIFO order`() {
        let queue = Queue<Int>.Linked {
            1
            2
            3
        }
        #expect(QueueLinkedBuilderTests.collected(queue) == [1, 2, 3])
    }

    @Test
    func `Optional element - some`() {
        let value: Int? = 42
        let queue = Queue<Int>.Linked { value }
        #expect(QueueLinkedBuilderTests.collected(queue) == [42])
    }

    @Test
    func `Optional element - none`() {
        let value: Int? = nil
        let queue = Queue<Int>.Linked { value }
        let isEmpty = queue.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `Mixed elements and optionals`() {
        let some: Int? = 2
        let none: Int? = nil
        let queue = Queue<Int>.Linked {
            1
            some
            none
            3
        }
        #expect(QueueLinkedBuilderTests.collected(queue) == [1, 2, 3])
    }

    @Test
    func `Empty block`() {
        let queue = Queue<Int>.Linked {}
        let isEmpty = queue.isEmpty
        #expect(isEmpty)
    }
}

// MARK: - Control Flow

extension QueueLinkedBuilderTests.Unit {

    @Test
    func `Conditional include`() {
        let include = true
        let queue = Queue<Int>.Linked {
            1
            if include {
                2
            }
            3
        }
        #expect(QueueLinkedBuilderTests.collected(queue) == [1, 2, 3])
    }

    @Test
    func `Conditional exclude`() {
        let include = false
        let queue = Queue<Int>.Linked {
            1
            if include {
                2
            }
            3
        }
        #expect(QueueLinkedBuilderTests.collected(queue) == [1, 3])
    }

    @Test
    func `If-else first branch`() {
        let condition = true
        let queue = Queue<Int>.Linked {
            if condition {
                1
            } else {
                2
            }
        }
        #expect(QueueLinkedBuilderTests.collected(queue) == [1])
    }

    @Test
    func `If-else second branch`() {
        let condition = false
        let queue = Queue<Int>.Linked {
            if condition {
                1
            } else {
                2
            }
        }
        #expect(QueueLinkedBuilderTests.collected(queue) == [2])
    }
}

// MARK: - Edge Cases

extension QueueLinkedBuilderTests.EdgeCase {

    @Test
    func `Deeply nested conditionals`() {
        let a = true
        let b = false
        let c = true
        let queue = Queue<Int>.Linked {
            0
            if a {
                1
                if b {
                    2
                } else {
                    3
                    if c {
                        4
                    }
                }
            }
            99
        }
        #expect(QueueLinkedBuilderTests.collected(queue) == [0, 1, 3, 4, 99])
    }

    @Test
    func `Many elements preserve FIFO order`() {
        let queue = Queue<Int>.Linked {
            1
            2
            3
            4
            5
            6
            7
            8
            9
            10
        }
        #expect(QueueLinkedBuilderTests.collected(queue) == Swift.Array(1...10))
    }
}

// MARK: - Integration

extension QueueLinkedBuilderTests.Integration {

    @Test
    func `Builder result accepts further enqueues`() {
        var queue = Queue<Int>.Linked {
            1
            2
        }
        queue.enqueue(3)
        queue.enqueue(4)
        #expect(QueueLinkedBuilderTests.collected(queue) == [1, 2, 3, 4])
    }
}

// MARK: - NonCopyable

extension QueueLinkedBuilderTests.NonCopyable {

    @Test
    func `Builder with single noncopyable element`() {
        let queue = Queue<Move>.Linked {
            Move(42)
        }
        #expect(QueueLinkedBuilderTests.collected(queue) == [42])
    }

    @Test
    func `Builder with multiple noncopyable elements`() {
        let queue = Queue<Move>.Linked {
            Move(1)
            Move(2)
            Move(3)
        }
        #expect(QueueLinkedBuilderTests.collected(queue) == [1, 2, 3])
    }

    @Test
    func `Builder with conditional noncopyable element - included`() {
        let include = true
        let queue = Queue<Move>.Linked {
            Move(1)
            if include {
                Move(2)
            }
            Move(3)
        }
        #expect(QueueLinkedBuilderTests.collected(queue) == [1, 2, 3])
    }

    @Test
    func `Builder with conditional noncopyable element - excluded`() {
        let include = false
        let queue = Queue<Move>.Linked {
            Move(1)
            if include {
                Move(2)
            }
            Move(3)
        }
        #expect(QueueLinkedBuilderTests.collected(queue) == [1, 3])
    }

    @Test
    func `Builder with if-else noncopyable`() {
        let condition = true
        let queue = Queue<Move>.Linked {
            if condition {
                Move(10)
            } else {
                Move(20)
            }
        }
        #expect(QueueLinkedBuilderTests.collected(queue) == [10])
    }

    @Test
    func `Empty noncopyable builder`() {
        let queue = Queue<Move>.Linked {}
        let isEmpty = queue.isEmpty
        #expect(isEmpty)
    }
}

// MARK: - Static Method Tests

extension QueueLinkedBuilderTests.StaticMethods {

    @Test
    func `buildExpression single element`() {
        let result = Queue<Int>.Linked.Builder.buildExpression(42)
        #expect(QueueLinkedBuilderTests.collected(result) == [42])
    }

    @Test
    func `buildExpression existing queue`() {
        let input: Queue<Int>.Linked = Queue<Int>.Linked { 1; 2; 3 }
        let result = Queue<Int>.Linked.Builder.buildExpression(input)
        #expect(QueueLinkedBuilderTests.collected(result) == [1, 2, 3])
    }

    @Test
    func `buildExpression optional - some`() {
        let value: Int? = 42
        let result = Queue<Int>.Linked.Builder.buildExpression(value)
        #expect(QueueLinkedBuilderTests.collected(result) == [42])
    }

    @Test
    func `buildExpression optional - none`() {
        let value: Int? = nil
        let result = Queue<Int>.Linked.Builder.buildExpression(value)
        let isEmpty = result.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `buildPartialBlock first`() {
        let first: Queue<Int>.Linked = Queue<Int>.Linked { 1; 2; 3 }
        let result = Queue<Int>.Linked.Builder.buildPartialBlock(first: first)
        #expect(QueueLinkedBuilderTests.collected(result) == [1, 2, 3])
    }

    @Test
    func `buildPartialBlock first void`() {
        let result = Queue<Int>.Linked.Builder.buildPartialBlock(first: ())
        let isEmpty = result.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `buildPartialBlock accumulated and next preserves FIFO order`() {
        let acc: Queue<Int>.Linked = Queue<Int>.Linked { 1; 2 }
        let next: Queue<Int>.Linked = Queue<Int>.Linked { 3; 4 }
        let result = Queue<Int>.Linked.Builder.buildPartialBlock(
            accumulated: acc,
            next: next
        )
        #expect(QueueLinkedBuilderTests.collected(result) == [1, 2, 3, 4])
    }

    @Test
    func `buildBlock empty`() {
        let result = Queue<Int>.Linked.Builder.buildBlock()
        let isEmpty = result.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `buildOptional some`() {
        let component: Queue<Int>.Linked? = Queue<Int>.Linked { 1; 2 }
        let result = Queue<Int>.Linked.Builder.buildOptional(component)
        #expect(QueueLinkedBuilderTests.collected(result) == [1, 2])
    }

    @Test
    func `buildOptional none`() {
        let component: Queue<Int>.Linked? = nil
        let result = Queue<Int>.Linked.Builder.buildOptional(component)
        let isEmpty = result.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `buildEither first`() {
        let first: Queue<Int>.Linked = Queue<Int>.Linked { 1; 2 }
        let result = Queue<Int>.Linked.Builder.buildEither(first: first)
        #expect(QueueLinkedBuilderTests.collected(result) == [1, 2])
    }

    @Test
    func `buildEither second`() {
        let second: Queue<Int>.Linked = Queue<Int>.Linked { 3; 4 }
        let result = Queue<Int>.Linked.Builder.buildEither(second: second)
        #expect(QueueLinkedBuilderTests.collected(result) == [3, 4])
    }

    @Test
    func `buildLimitedAvailability passthrough`() {
        let component: Queue<Int>.Linked = Queue<Int>.Linked { 1; 2; 3 }
        let result = Queue<Int>.Linked.Builder.buildLimitedAvailability(component)
        #expect(QueueLinkedBuilderTests.collected(result) == [1, 2, 3])
    }
}
