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

public import Queue_Dynamic_Primitives
public import Queue_Primitives_Core

extension Queue.Fixed where Element: ~Copyable {
    /// Constructs a heap-allocated bounded FIFO queue from a result-builder closure.
    ///
    /// Wraps the dynamic `Queue<Element>.Builder` per Round-2 Option Y.
    /// FIFO; capacity supplied at outer init; overflow throws `Error`.
    public init(
        capacity: Index<Element>.Count,
        @Queue<Element>.Builder _ builder: () -> Queue<Element>
    ) throws(Queue.Fixed.Error) {
        var fixed = Queue<Element>.Fixed(capacity: capacity)
        var dynamic = builder()
        while let elem = dynamic.dequeue() {
            try fixed.enqueue(consume elem)
        }
        self = fixed
    }
}
