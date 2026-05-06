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

@Suite("Queue.Builder")
struct QueueBuilderTests {
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

extension QueueBuilderTests {
    fileprivate static func collected(
        _ queue: consuming Queue<Int>
    ) -> [Int] {
        var rest = consume queue
        var result: [Int] = []
        while let elem = rest.dequeue() {
            result.append(elem)
        }
        return result
    }

    fileprivate static func collected(
        _ queue: consuming Queue<Move>
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

extension QueueBuilderTests.FIFOSemantics {

    @Test
    func `Declaration order = enqueue order = dequeue order`() {
        var queue = Queue<Int> {
            1
            2
            3
        }
        #expect(queue.dequeue() == 1)
        #expect(queue.dequeue() == 2)
        #expect(queue.dequeue() == 3)
        #expect(queue.dequeue() == nil)
    }

    @Test
    func `Builder is equivalent to imperative enqueue sequence`() {
        let viaBuilder = Queue<Int> {
            10
            20
            30
        }
        var viaImperative = Queue<Int>()
        viaImperative.enqueue(10)
        viaImperative.enqueue(20)
        viaImperative.enqueue(30)
        #expect(
            QueueBuilderTests.collected(viaBuilder)
                == QueueBuilderTests.collected(viaImperative)
        )
    }
}

// MARK: - Unit Tests

extension QueueBuilderTests.Unit {

    @Test
    func `Single element expression`() {
        let queue = Queue<Int> { 42 }
        #expect(QueueBuilderTests.collected(queue) == [42])
    }

    @Test
    func `Multiple element expressions in FIFO order`() {
        let queue = Queue<Int> {
            1
            2
            3
        }
        #expect(QueueBuilderTests.collected(queue) == [1, 2, 3])
    }

    @Test
    func `Optional element - some`() {
        let value: Int? = 42
        let queue = Queue<Int> { value }
        #expect(QueueBuilderTests.collected(queue) == [42])
    }

    @Test
    func `Optional element - none`() {
        let value: Int? = nil
        let queue = Queue<Int> { value }
        let isEmpty = queue.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `Mixed elements and optionals`() {
        let some: Int? = 2
        let none: Int? = nil
        let queue = Queue<Int> {
            1
            some
            none
            3
        }
        #expect(QueueBuilderTests.collected(queue) == [1, 2, 3])
    }

    @Test
    func `Empty block`() {
        let queue = Queue<Int> {}
        let isEmpty = queue.isEmpty
        #expect(isEmpty)
    }
}

// MARK: - Control Flow

extension QueueBuilderTests.Unit {

    @Test
    func `Conditional include`() {
        let include = true
        let queue = Queue<Int> {
            1
            if include {
                2
            }
            3
        }
        #expect(QueueBuilderTests.collected(queue) == [1, 2, 3])
    }

    @Test
    func `Conditional exclude`() {
        let include = false
        let queue = Queue<Int> {
            1
            if include {
                2
            }
            3
        }
        #expect(QueueBuilderTests.collected(queue) == [1, 3])
    }

    @Test
    func `If-else first branch`() {
        let condition = true
        let queue = Queue<Int> {
            if condition {
                1
            } else {
                2
            }
        }
        #expect(QueueBuilderTests.collected(queue) == [1])
    }

    @Test
    func `If-else second branch`() {
        let condition = false
        let queue = Queue<Int> {
            if condition {
                1
            } else {
                2
            }
        }
        #expect(QueueBuilderTests.collected(queue) == [2])
    }
}

// MARK: - Edge Cases

extension QueueBuilderTests.EdgeCase {

    @Test
    func `Deeply nested conditionals`() {
        let a = true
        let b = false
        let c = true
        let queue = Queue<Int> {
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
        #expect(QueueBuilderTests.collected(queue) == [0, 1, 3, 4, 99])
    }

    @Test
    func `Many elements preserve FIFO order`() {
        let queue = Queue<Int> {
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
        #expect(QueueBuilderTests.collected(queue) == Swift.Array(1...10))
    }
}

// MARK: - Integration

extension QueueBuilderTests.Integration {

    @Test
    func `Builder result accepts further enqueues`() {
        var queue = Queue<Int> {
            1
            2
        }
        queue.enqueue(3)
        queue.enqueue(4)
        #expect(QueueBuilderTests.collected(queue) == [1, 2, 3, 4])
    }
}

// MARK: - NonCopyable

extension QueueBuilderTests.NonCopyable {

    @Test
    func `Builder with single noncopyable element`() {
        let queue = Queue<Move> {
            Move(42)
        }
        #expect(QueueBuilderTests.collected(queue) == [42])
    }

    @Test
    func `Builder with multiple noncopyable elements`() {
        let queue = Queue<Move> {
            Move(1)
            Move(2)
            Move(3)
        }
        #expect(QueueBuilderTests.collected(queue) == [1, 2, 3])
    }

    @Test
    func `Builder with conditional noncopyable element - included`() {
        let include = true
        let queue = Queue<Move> {
            Move(1)
            if include {
                Move(2)
            }
            Move(3)
        }
        #expect(QueueBuilderTests.collected(queue) == [1, 2, 3])
    }

    @Test
    func `Builder with conditional noncopyable element - excluded`() {
        let include = false
        let queue = Queue<Move> {
            Move(1)
            if include {
                Move(2)
            }
            Move(3)
        }
        #expect(QueueBuilderTests.collected(queue) == [1, 3])
    }

    @Test
    func `Builder with if-else noncopyable`() {
        let condition = true
        let queue = Queue<Move> {
            if condition {
                Move(10)
            } else {
                Move(20)
            }
        }
        #expect(QueueBuilderTests.collected(queue) == [10])
    }

    @Test
    func `Empty noncopyable builder`() {
        let queue = Queue<Move> {}
        let isEmpty = queue.isEmpty
        #expect(isEmpty)
    }
}

// MARK: - Static Method Tests

extension QueueBuilderTests.StaticMethods {

    @Test
    func `buildExpression single element`() {
        let result = Queue<Int>.Builder.buildExpression(42)
        #expect(QueueBuilderTests.collected(result) == [42])
    }

    @Test
    func `buildExpression existing queue`() {
        let input: Queue<Int> = Queue<Int> { 1; 2; 3 }
        let result = Queue<Int>.Builder.buildExpression(input)
        #expect(QueueBuilderTests.collected(result) == [1, 2, 3])
    }

    @Test
    func `buildExpression optional - some`() {
        let value: Int? = 42
        let result = Queue<Int>.Builder.buildExpression(value)
        #expect(QueueBuilderTests.collected(result) == [42])
    }

    @Test
    func `buildExpression optional - none`() {
        let value: Int? = nil
        let result = Queue<Int>.Builder.buildExpression(value)
        let isEmpty = result.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `buildPartialBlock first`() {
        let first: Queue<Int> = Queue<Int> { 1; 2; 3 }
        let result = Queue<Int>.Builder.buildPartialBlock(first: first)
        #expect(QueueBuilderTests.collected(result) == [1, 2, 3])
    }

    @Test
    func `buildPartialBlock first void`() {
        let result = Queue<Int>.Builder.buildPartialBlock(first: ())
        let isEmpty = result.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `buildPartialBlock accumulated and next preserves FIFO order`() {
        let acc: Queue<Int> = Queue<Int> { 1; 2 }
        let next: Queue<Int> = Queue<Int> { 3; 4 }
        let result = Queue<Int>.Builder.buildPartialBlock(
            accumulated: acc,
            next: next
        )
        #expect(QueueBuilderTests.collected(result) == [1, 2, 3, 4])
    }

    @Test
    func `buildBlock empty`() {
        let result = Queue<Int>.Builder.buildBlock()
        let isEmpty = result.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `buildOptional some`() {
        let component: Queue<Int>? = Queue<Int> { 1; 2 }
        let result = Queue<Int>.Builder.buildOptional(component)
        #expect(QueueBuilderTests.collected(result) == [1, 2])
    }

    @Test
    func `buildOptional none`() {
        let component: Queue<Int>? = nil
        let result = Queue<Int>.Builder.buildOptional(component)
        let isEmpty = result.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `buildEither first`() {
        let first: Queue<Int> = Queue<Int> { 1; 2 }
        let result = Queue<Int>.Builder.buildEither(first: first)
        #expect(QueueBuilderTests.collected(result) == [1, 2])
    }

    @Test
    func `buildEither second`() {
        let second: Queue<Int> = Queue<Int> { 3; 4 }
        let result = Queue<Int>.Builder.buildEither(second: second)
        #expect(QueueBuilderTests.collected(result) == [3, 4])
    }

    @Test
    func `buildLimitedAvailability passthrough`() {
        let component: Queue<Int> = Queue<Int> { 1; 2; 3 }
        let result = Queue<Int>.Builder.buildLimitedAvailability(component)
        #expect(QueueBuilderTests.collected(result) == [1, 2, 3])
    }
}
