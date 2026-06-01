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

public import Queue_Primitive
public import Queue_Primitive

extension Queue.Static where Element: ~Copyable {
    /// Constructs a fixed-capacity inline queue from a result-builder closure.
    ///
    /// Wraps the dynamic `Queue<Element>.Builder` per Round-2 Option Y.
    /// FIFO: declaration order = enqueue order = dequeue order. Overflow
    /// throws `Error` from `Queue.Static.enqueue`.
    public init(
        @Queue<Element>.Builder _ builder: () -> Queue<Element>
    ) throws(Self.Error) {
        var dynamic = builder()
        self.init()
        while let elem = dynamic.dequeue() {
            try self.enqueue(consume elem)
        }
    }
}
