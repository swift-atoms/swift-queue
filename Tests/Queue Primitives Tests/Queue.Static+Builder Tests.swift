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

private struct StaticQM: ~Copyable {
    let v: Int
    init(_ v: Int) { self.v = v }
}

@Suite("Queue.Static+Builder")
struct QueueStaticBuilderTests {
    @Suite struct Within {}
    @Suite struct Overflow {}
    @Suite struct NC {}
}

extension QueueStaticBuilderTests.Within {
    @Test
    func `within capacity FIFO order`() throws {
        var q = try Queue<Int>.Static<8> { 1; 2; 3 }
        #expect(q.dequeue() == 1)
        #expect(q.dequeue() == 2)
        #expect(q.dequeue() == 3)
    }
}

extension QueueStaticBuilderTests.Overflow {
    @Test
    func `throws on overflow`() {
        do {
            _ = try Queue<Int>.Static<2> { 1; 2; 3 }
            Issue.record("expected throw")
        } catch let e {
            #expect(e == .overflow)
        }
    }
}

extension QueueStaticBuilderTests.NC {
    @Test
    func `noncopyable element within capacity`() throws {
        let q = try Queue<StaticQM>.Static<4> { StaticQM(1); StaticQM(2); StaticQM(3) }
        let isEmpty = q.isEmpty
        #expect(!isEmpty)
    }
}
