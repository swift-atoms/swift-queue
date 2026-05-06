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

private struct SmallQM: ~Copyable {
    let v: Int
    init(_ v: Int) { self.v = v }
}

@Suite("Queue.Small+Builder")
struct QueueSmallBuilderTests {
    @Suite struct Within {}
    @Suite struct Spill {}
    @Suite struct NC {}
}

extension QueueSmallBuilderTests.Within {
    @Test
    func `within inline capacity`() {
        var q = Queue<Int>.Small<8> { 1; 2; 3 }
        #expect(q.dequeue() == 1)
    }
}

extension QueueSmallBuilderTests.Spill {
    @Test
    func `spills to heap`() {
        var q = Queue<Int>.Small<2> { 1; 2; 3; 4; 5 }
        #expect(q.dequeue() == 1)
        #expect(q.dequeue() == 2)
        #expect(q.dequeue() == 3)
    }
}

extension QueueSmallBuilderTests.NC {
    @Test
    func `noncopyable element spills`() {
        let q = Queue<SmallQM>.Small<2> { SmallQM(1); SmallQM(2); SmallQM(3) }
        let isEmpty = q.isEmpty
        #expect(!isEmpty)
    }
}
