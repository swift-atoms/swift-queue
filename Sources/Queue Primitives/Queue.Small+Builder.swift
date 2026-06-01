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

extension Queue.Small where Element: ~Copyable {
    /// Constructs a SmallVec queue from a result-builder closure.
    ///
    /// Wraps the dynamic `Queue<Element>.Builder` per Round-2 Option Y.
    /// FIFO; non-throwing because Small spills to heap on overflow.
    public init(
        @Queue<Element>.Builder _ builder: () -> Queue<Element>
    ) {
        var dynamic = builder()
        self.init()
        while let elem = dynamic.dequeue() {
            self.enqueue(consume elem)
        }
    }
}
