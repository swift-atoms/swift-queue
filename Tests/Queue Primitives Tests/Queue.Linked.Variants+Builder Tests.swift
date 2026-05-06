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

@Suite("Queue.Linked variants + Builder")
struct QueueLinkedVariantsBuilderTests {
    @Suite struct Inline {}
    @Suite struct Small {}
    @Suite struct Fixed {}
}

extension QueueLinkedVariantsBuilderTests.Inline {
    @Test
    func `Inline within capacity`() throws {
        var q = try Queue<Int>.Linked.Inline<8> { 1; 2; 3 }
        #expect(q.dequeue() == 1)
    }

    @Test
    func `Inline throws on overflow`() {
        do {
            _ = try Queue<Int>.Linked.Inline<2> { 1; 2; 3 }
            Issue.record("expected throw")
        } catch {
            // expected
        }
    }
}

extension QueueLinkedVariantsBuilderTests.Small {
    @Test
    func `Small spills to heap`() throws {
        var q = try Queue<Int>.Linked.Small<2> { 1; 2; 3; 4; 5 }
        #expect(q.dequeue() == 1)
    }
}

extension QueueLinkedVariantsBuilderTests.Fixed {
    @Test
    func `Fixed within capacity`() throws {
        var q = try Queue<Int>.Linked.Fixed(capacity: 8) { 1; 2; 3 }
        #expect(q.dequeue() == 1)
    }

    @Test
    func `Fixed throws on overflow`() {
        do {
            _ = try Queue<Int>.Linked.Fixed(capacity: 2) { 1; 2; 3 }
            Issue.record("expected throw")
        } catch {
            // expected
        }
    }
}
