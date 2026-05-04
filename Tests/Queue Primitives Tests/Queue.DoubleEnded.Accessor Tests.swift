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

@Suite("Queue.DoubleEnded - Accessor API")
struct QueueDoubleEndedAccessorTests {

    // MARK: - Copyable

    @Suite("Copyable elements")
    struct CopyableTests {

        @Test
        func `front.push and front.take`() {
            var deque = Queue<Int>.DoubleEnded()
            deque.front.push(1)
            deque.front.push(2)
            deque.front.push(3)

            #expect(deque.count == 3)
            #expect(deque.front.take == 3)
            #expect(deque.front.take == 2)
            #expect(deque.front.take == 1)
            if let _ = deque.front.take { Issue.record("Expected nil from front.take") }
        }

        @Test
        func `back.push and back.take`() {
            var deque = Queue<Int>.DoubleEnded()
            deque.back.push(1)
            deque.back.push(2)
            deque.back.push(3)

            #expect(deque.count == 3)
            #expect(deque.back.take == 3)
            #expect(deque.back.take == 2)
            #expect(deque.back.take == 1)
            if let _ = deque.back.take { Issue.record("Expected nil from back.take") }
        }

        @Test
        func `front.pop throws on empty`() {
            var deque = Queue<Int>.DoubleEnded()
            #expect(throws: Queue<Int>.DoubleEnded.Error.empty) {
                try deque.front.pop()
            }
        }

        @Test
        func `back.pop throws on empty`() {
            var deque = Queue<Int>.DoubleEnded()
            #expect(throws: Queue<Int>.DoubleEnded.Error.empty) {
                try deque.back.pop()
            }
        }

        @Test
        func `front.peek returns value without removal`() {
            var deque = Queue<Int>.DoubleEnded()
            deque.back.push(10)
            deque.back.push(20)

            #expect(deque.front.peek == 10)
            #expect(deque.count == 2)
        }

        @Test
        func `back.peek returns value without removal`() {
            var deque = Queue<Int>.DoubleEnded()
            deque.back.push(10)
            deque.back.push(20)

            #expect(deque.back.peek == 20)
            #expect(deque.count == 2)
        }

        @Test
        func `front.peek closure-based`() {
            var deque = Queue<Int>.DoubleEnded()
            deque.back.push(42)

            let result = deque.front.peek { $0 * 2 }
            #expect(result == 84)
            #expect(deque.count == 1)
        }

        @Test
        func `mixed front and back operations`() throws {
            var deque = Queue<Int>.DoubleEnded()
            deque.back.push(2)
            deque.back.push(3)
            deque.front.push(1)
            deque.front.push(0)

            // Order should be: 0, 1, 2, 3
            #expect(try deque.front.pop() == 0)
            #expect(try deque.front.pop() == 1)
            #expect(try deque.back.pop() == 3)
            #expect(try deque.back.pop() == 2)
            #expect(deque.isEmpty)
        }

        @Test
        func `peek on empty returns nil`() {
            var deque = Queue<Int>.DoubleEnded()
            #expect(deque.front.peek == nil)
            #expect(deque.back.peek == nil)
            #expect(deque.front.peek { $0 } == nil)
            #expect(deque.back.peek { $0 } == nil)
        }
    }

    // MARK: - ~Copyable

    @Suite("~Copyable elements")
    struct NonCopyableTests {

        struct Token: ~Copyable {
            let id: Int
        }

        @Test
        func `front.push and front.take`() {
            var deque = Queue<Token>.DoubleEnded()
            deque.front.push(Token(id: 1))
            deque.front.push(Token(id: 2))

            if let token = deque.front.take {
                #expect(token.id == 2)
            } else {
                Issue.record("Expected token")
            }

            if let token = deque.front.take {
                #expect(token.id == 1)
            } else {
                Issue.record("Expected token")
            }

            if let _ = deque.front.take { Issue.record("Expected nil from front.take") }
        }

        @Test
        func `back.push and back.take`() {
            var deque = Queue<Token>.DoubleEnded()
            deque.back.push(Token(id: 1))
            deque.back.push(Token(id: 2))

            if let token = deque.back.take {
                #expect(token.id == 2)
            } else {
                Issue.record("Expected token")
            }

            if let token = deque.back.take {
                #expect(token.id == 1)
            } else {
                Issue.record("Expected token")
            }

            if let _ = deque.back.take { Issue.record("Expected nil from back.take") }
        }

        @Test
        func `front.pop throws on empty`() {
            var deque = Queue<Token>.DoubleEnded()
            #expect(throws: Queue<Token>.DoubleEnded.Error.empty) {
                try deque.front.pop()
            }
        }

        @Test
        func `back.pop throws on empty`() {
            var deque = Queue<Token>.DoubleEnded()
            #expect(throws: Queue<Token>.DoubleEnded.Error.empty) {
                try deque.back.pop()
            }
        }

        @Test
        func `front.peek borrows without removal`() {
            var deque = Queue<Token>.DoubleEnded()
            deque.back.push(Token(id: 42))

            let peekedId = deque.front.peek { $0.id }
            #expect(peekedId == 42)
            #expect(deque.count == 1)
        }

        @Test
        func `back.peek borrows without removal`() {
            var deque = Queue<Token>.DoubleEnded()
            deque.back.push(Token(id: 99))

            let peekedId = deque.back.peek { $0.id }
            #expect(peekedId == 99)
            #expect(deque.count == 1)
        }

        @Test
        func `peek on empty returns nil`() {
            var deque = Queue<Token>.DoubleEnded()
            let result = deque.front.peek { $0.id }
            #expect(result == nil)

            let backResult = deque.back.peek { $0.id }
            #expect(backResult == nil)
        }

        @Test
        func `mixed front and back operations`() throws {
            var deque = Queue<Token>.DoubleEnded()
            deque.back.push(Token(id: 2))
            deque.back.push(Token(id: 3))
            deque.front.push(Token(id: 1))

            // Order: 1, 2, 3
            let first = try deque.front.pop()
            #expect(first.id == 1)

            let last = try deque.back.pop()
            #expect(last.id == 3)

            let middle = try deque.front.pop()
            #expect(middle.id == 2)

            let isEmpty = deque.isEmpty
            #expect(isEmpty)
        }
    }
}
