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

private struct FixedQM: ~Copyable {
    let v: Int
    init(_ v: Int) { self.v = v }
}

@Suite("Queue.Fixed+Builder")
struct QueueFixedBuilderTests {
    @Suite struct Within {}
    @Suite struct Overflow {}
    @Suite struct NC {}
}

extension QueueFixedBuilderTests.Within {
    @Test
    func `within capacity`() throws {
        var q = try Queue<Int>.Fixed(capacity: 8) { 1; 2; 3 }
        #expect(q.dequeue() == 1)
    }
}

extension QueueFixedBuilderTests.Overflow {
    @Test
    func `throws on overflow`() {
        do {
            _ = try Queue<Int>.Fixed(capacity: 2) { 1; 2; 3 }
            Issue.record("expected throw")
        } catch let e {
            #expect(e == .overflow)
        }
    }
}

extension QueueFixedBuilderTests.NC {
    @Test
    func `noncopyable element within capacity`() throws {
        let q = try Queue<FixedQM>.Fixed(capacity: 4) { FixedQM(1); FixedQM(2) }
        let isEmpty = q.isEmpty
        #expect(!isEmpty)
    }
}
